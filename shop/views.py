from decimal import Decimal
import uuid

from django.contrib import messages
from django.contrib.auth.decorators import login_required
from django.shortcuts import get_object_or_404, redirect, render

from .models import Category, Product, Wishlist, Order, OrderItem


def get_cart(request):
    return request.session.get("cart", {})


def save_cart(request, cart):
    request.session["cart"] = cart
    request.session.modified = True


def cart_count(request):
    cart = get_cart(request)
    return sum(int(quantity) for quantity in cart.values())


def home(request):
    categories = Category.objects.filter(active=True)

    products = Product.objects.filter(
        active=True,
        featured=True
    ).select_related("category")

    query = request.GET.get("q", "").strip()
    category_slug = request.GET.get("category", "").strip()

    if query:
        products = products.filter(name__icontains=query)

    if category_slug:
        products = products.filter(
            category__slug=category_slug
        )

    return render(
        request,
        "home.html",
        {
            "categories": categories,
            "products": products,
            "cart_count": cart_count(request),
        },
    )


def product_detail(request, slug):
    product = get_object_or_404(
        Product.objects.select_related("category"),
        slug=slug,
        active=True,
    )

    related_products = Product.objects.filter(
        category=product.category,
        active=True,
    ).exclude(
        id=product.id
    )[:4]

    return render(
        request,
        "shop/product_detail.html",
        {
            "product": product,
            "related_products": related_products,
            "cart_count": cart_count(request),
        },
    )


def add_to_cart(request, product_id):
    product = get_object_or_404(
        Product,
        id=product_id,
        active=True,
    )

    cart = get_cart(request)

    product_key = str(product.id)

    current_quantity = int(
        cart.get(product_key, 0)
    )

    if current_quantity >= product.stock:
        messages.warning(
            request,
            "Maximum available stock reached."
        )
        return redirect("shop:cart")

    cart[product_key] = current_quantity + 1

    save_cart(request, cart)

    messages.success(
        request,
        f"{product.name} added to your cart."
    )

    return redirect("shop:cart")


def remove_from_cart(request, product_id):
    cart = get_cart(request)

    product_key = str(product_id)

    if product_key in cart:
        del cart[product_key]
        save_cart(request, cart)

    return redirect("shop:cart")


def update_cart(request, product_id):
    cart = get_cart(request)

    product_key = str(product_id)

    if request.method == "POST":

        try:
            quantity = int(
                request.POST.get("quantity", 1)
            )
        except (TypeError, ValueError):
            quantity = 1

        product = get_object_or_404(
            Product,
            id=product_id,
            active=True,
        )

        if quantity <= 0:
            cart.pop(product_key, None)

        elif quantity > product.stock:
            cart[product_key] = product.stock

        else:
            cart[product_key] = quantity

        save_cart(request, cart)

    return redirect("shop:cart")


def cart(request):
    cart_data = get_cart(request)

    items = []
    subtotal = Decimal("0.00")

    for product_id, quantity in cart_data.items():

        try:
            product = Product.objects.get(
                id=int(product_id),
                active=True,
            )
        except Product.DoesNotExist:
            continue

        quantity = int(quantity)

        item_total = (
            product.price * quantity
        )

        subtotal += item_total

        items.append(
            {
                "product": product,
                "quantity": quantity,
                "total": item_total,
            }
        )

    shipping = Decimal("0.00")

    if subtotal > 0 and subtotal < Decimal("999"):
        shipping = Decimal("99.00")

    total = subtotal + shipping

    return render(
        request,
        "shop/cart.html",
        {
            "items": items,
            "subtotal": subtotal,
            "shipping": shipping,
            "total": total,
            "cart_count": cart_count(request),
        },
    )


@login_required
def toggle_wishlist(request, product_id):
    product = get_object_or_404(
        Product,
        id=product_id,
        active=True,
    )

    wishlist_item = Wishlist.objects.filter(
        user=request.user,
        product=product,
    ).first()

    if wishlist_item:
        wishlist_item.delete()

        messages.info(
            request,
            "Product removed from wishlist."
        )

    else:
        Wishlist.objects.create(
            user=request.user,
            product=product,
        )

        messages.success(
            request,
            "Product added to wishlist."
        )

    return redirect(
        request.META.get(
            "HTTP_REFERER",
            "shop:home"
        )
    )


@login_required
def wishlist(request):
    wishlist_items = Wishlist.objects.filter(
        user=request.user
    ).select_related("product", "product__category")

    return render(
        request,
        "shop/wishlist.html",
        {
            "wishlist_items": wishlist_items,
            "cart_count": cart_count(request),
        },
    )


@login_required
def checkout(request):

    cart_data = get_cart(request)

    if not cart_data:
        messages.warning(
            request,
            "Your cart is empty."
        )
        return redirect("shop:home")

    items = []
    subtotal = Decimal("0.00")

    for product_id, quantity in cart_data.items():

        try:
            product = Product.objects.get(
                id=int(product_id),
                active=True,
            )
        except Product.DoesNotExist:
            continue

        quantity = int(quantity)

        if quantity > product.stock:
            messages.error(
                request,
                f"Only {product.stock} units of "
                f"{product.name} are available."
            )
            return redirect("shop:cart")

        item_total = (
            product.price * quantity
        )

        subtotal += item_total

        items.append(
            {
                "product": product,
                "quantity": quantity,
                "total": item_total,
            }
        )

    shipping = Decimal("0.00")

    if subtotal < Decimal("999"):
        shipping = Decimal("99.00")

    total = subtotal + shipping

    if request.method == "POST":

        order_number = (
            "KLS-"
            + uuid.uuid4().hex[:10].upper()
        )

        order = Order.objects.create(
            user=request.user,
            order_number=order_number,
            total=total,
            status="PLACED",
        )

        for item in items:

            OrderItem.objects.create(
                order=order,
                product=item["product"],
                quantity=item["quantity"],
                price=item["product"].price,
            )

            item["product"].stock -= item["quantity"]
            item["product"].save(
                update_fields=["stock"]
            )

        request.session["cart"] = {}
        request.session.modified = True

        return redirect(
            "shop:order_success",
            order_number=order.order_number,
        )

    return render(
        request,
        "shop/checkout.html",
        {
            "items": items,
            "subtotal": subtotal,
            "shipping": shipping,
            "total": total,
            "cart_count": cart_count(request),
        },
    )


@login_required
def order_success(request, order_number):

    order = get_object_or_404(
        Order,
        order_number=order_number,
        user=request.user,
    )

    return render(
        request,
        "shop/order_success.html",
        {
            "order": order,
            "cart_count": cart_count(request),
        },
    )


@login_required
def dashboard(request):

    orders = Order.objects.filter(
        user=request.user
    ).prefetch_related(
        "items",
        "items__product",
    )

    wishlist_items = Wishlist.objects.filter(
        user=request.user
    ).select_related("product")

    return render(
        request,
        "shop/dashboard.html",
        {
            "orders": orders,
            "wishlist_items": wishlist_items,
            "cart_count": cart_count(request),
        },
    )
from django.urls import path

from . import views


app_name = "shop"


urlpatterns = [

    path(
        "",
        views.home,
        name="home",
    ),

    path(
        "product/<slug:slug>/",
        views.product_detail,
        name="product_detail",
    ),

    path(
        "cart/",
        views.cart,
        name="cart",
    ),

    path(
        "cart/add/<int:product_id>/",
        views.add_to_cart,
        name="add_to_cart",
    ),

    path(
        "cart/remove/<int:product_id>/",
        views.remove_from_cart,
        name="remove_from_cart",
    ),

    path(
        "cart/update/<int:product_id>/",
        views.update_cart,
        name="update_cart",
    ),

    path(
        "wishlist/",
        views.wishlist,
        name="wishlist",
    ),

    path(
        "wishlist/toggle/<int:product_id>/",
        views.toggle_wishlist,
        name="toggle_wishlist",
    ),

    path(
        "checkout/",
        views.checkout,
        name="checkout",
    ),

    path(
        "order/success/<str:order_number>/",
        views.order_success,
        name="order_success",
    ),

    path(
        "dashboard/",
        views.dashboard,
        name="dashboard",
    ),
]
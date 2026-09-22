from django.core.management.base import BaseCommand
from django.utils.text import slugify

from shop.models import Category, Product


class Command(BaseCommand):
    help = "Create ShopSphere demo categories and products"

    def handle(self, *args, **options):

        data = [
            {
                "category": "Electronics",
                "icon": "💻",
                "products": [
                    {
                        "name": "Wireless Headphones",
                        "price": 59.99,
                        "compare_price": 89.99,
                        "rating": 4.5,
                        "reviews": 120,
                    },
                    {
                        "name": "Smart Watch",
                        "price": 99.99,
                        "compare_price": 149.99,
                        "rating": 4.3,
                        "reviews": 98,
                    },
                ],
            },

            {
                "category": "Fashion",
                "icon": "👕",
                "products": [
                    {
                        "name": "Running Shoes",
                        "price": 49.99,
                        "compare_price": 79.99,
                        "rating": 4.6,
                        "reviews": 210,
                    },
                    {
                        "name": "Leather Handbag",
                        "price": 69.99,
                        "compare_price": 109.99,
                        "rating": 4.4,
                        "reviews": 87,
                    },
                ],
            },

            {
                "category": "Home & Living",
                "icon": "🛋️",
                "products": [
                    {
                        "name": "Modern Table Lamp",
                        "price": 39.99,
                        "compare_price": 59.99,
                        "rating": 4.7,
                        "reviews": 76,
                    },
                ],
            },

            {
                "category": "Beauty",
                "icon": "💄",
                "products": [
                    {
                        "name": "Daily Skincare Kit",
                        "price": 29.99,
                        "compare_price": 44.99,
                        "rating": 4.5,
                        "reviews": 64,
                    },
                ],
            },

            {
                "category": "Sports",
                "icon": "👟",
                "products": [
                    {
                        "name": "Fitness Bottle",
                        "price": 19.99,
                        "compare_price": 29.99,
                        "rating": 4.4,
                        "reviews": 51,
                    },
                ],
            },

            {
                "category": "Books",
                "icon": "📚",
                "products": [
                    {
                        "name": "Modern Business Guide",
                        "price": 24.99,
                        "compare_price": 34.99,
                        "rating": 4.8,
                        "reviews": 33,
                    },
                ],
            },
        ]

        for item in data:

            category, _ = Category.objects.update_or_create(
                slug=slugify(item["category"]),
                defaults={
                    "name": item["category"],
                    "icon": item["icon"],
                    "active": True,
                },
            )

            for product in item["products"]:

                Product.objects.update_or_create(
                    slug=slugify(product["name"]),
                    defaults={
                        "category": category,
                        "name": product["name"],

                        "short_description":
                            f"Premium {product['name']} for everyday use.",

                        "description":
                            f"Discover our premium {product['name']} "
                            "with excellent quality and modern design.",

                        "price": product["price"],

                        "compare_at_price":
                            product["compare_price"],

                        "rating": product["rating"],

                        "review_count":
                            product["reviews"],

                        "stock": 25,

                        "featured": True,

                        "active": True,
                    },
                )

        self.stdout.write(
            self.style.SUCCESS(
                "ShopSphere demo data created successfully!"
            )
        )
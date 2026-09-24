from django.test import TestCase
from django.urls import reverse

class SmokeTests(TestCase):
    def test_home_page(self):
        response = self.client.get(reverse("shop:home"))
        self.assertEqual(response.status_code, 200)

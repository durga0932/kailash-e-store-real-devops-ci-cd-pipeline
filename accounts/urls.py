from django.urls import path

from .views import (
    UserLoginView,
    signup_view,
    logout_view,
)


app_name = "accounts"


urlpatterns = [
    path(
        "login/",
        UserLoginView.as_view(),
        name="login",
    ),

    path(
        "signup/",
        signup_view,
        name="signup",
    ),

    path(
        "logout/",
        logout_view,
        name="logout",
    ),
]
from django.urls import path

from accounts.views import RegisterView, LoginView, UserPasswordUpdateAPI, ProfileUpdateAPI

urlpatterns = [
    path("register/", RegisterView.as_view(), name='register'),
    path("login/", LoginView.as_view(), name='login'),
    path('update_password/', UserPasswordUpdateAPI.as_view(), name='update_password'),
    path('user/<int:user_id>/profile/', ProfileUpdateAPI.as_view(), name='profile_update'),
]
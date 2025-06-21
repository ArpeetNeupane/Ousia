from django.urls import path

from accounts.views import RegisterView, LoginView, UserPasswordUpdateAPI

urlpatterns = [
    path("register/", RegisterView.as_view(), name='register'),
    path("login/", LoginView.as_view(), name='login'),
    path('update_password/', UserPasswordUpdateAPI.as_view(), name='update_password')
]
from django.urls import path

from accounts.views import RegisterView, LoginView, UserPasswordUpdateAPI, ProfileUpdateAPI, ProfileAdminUpdateAPI

urlpatterns = [
    path("register/", RegisterView.as_view(), name='register'),
    path("login/", LoginView.as_view(), name='login'),
    path('update_password/', UserPasswordUpdateAPI.as_view(), name='update_password'),
    path('user/profile/', ProfileUpdateAPI.as_view(), name='profile_update'),
    path("user/<int:user_id>/profile/", ProfileAdminUpdateAPI.as_view(), name='profile_update_for_admins')
]
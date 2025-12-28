from django.urls import path

from accounts.views import RegisterView, LoginView, UserPasswordUpdateAPI, ProfileResponseAPI, ProfileUpdateAPI, ProfileAdminUpdateAPI

urlpatterns = [
    path("register/", RegisterView.as_view(), name='register'),
    path("login/", LoginView.as_view(), name='login'),
    path('update_password/', UserPasswordUpdateAPI.as_view(), name='update-password'),
    path('user/profile/', ProfileResponseAPI.as_view(), name='profile-retrieve'),
    path('user/profile_update/', ProfileUpdateAPI.as_view(), name='profile-update'),
    path("user/<int:user_id>/profile/", ProfileAdminUpdateAPI.as_view(), name='profile-update-for-admins'),
]
from django.urls import path

from accounts.views import (
    DeleteAccountAPI, RegisterView, LoginView, UserPasswordUpdateAPI,
    ProfileResponseAPI, ProfileUpdateAPI, ProfileAdminUpdateAPI, UserProfileDetailAPI,
    AreaOfInterestListCreateAPI, AreaOfInterestRetrieveAPI, AreaOfInterestUpdateAPI, AreaOfInterestDeleteAPI,
    UserAreaOfInterestListCreateAPI, UserAreaOfInterestRetrieveAPI, UserAreaOfInterestDeleteAPI, UserSearchAPI,
    ForgotPasswordAPI, VerifyOTPAPI, ResetPasswordAPI,
    DeviceTokenRegisterAPI, DeviceTokenUnregisterAPI,
)
urlpatterns = [
    path("register/", RegisterView.as_view(), name='register'),
    path("login/", LoginView.as_view(), name='login'),
    path('update_password/', UserPasswordUpdateAPI.as_view(), name='update-password'),
    path('user/profile/', ProfileResponseAPI.as_view(), name='profile-retrieve'),
    path('user/profile_update/', ProfileUpdateAPI.as_view(), name='profile-update'),
    path("user/<int:user_id>/profile/", ProfileAdminUpdateAPI.as_view(), name='profile-update-for-admins'),
    path('user/profile/<int:user_id>/', UserProfileDetailAPI.as_view(), name='user-profile-detail'),
    path('user/delete-account/', DeleteAccountAPI.as_view(), name='delete-account'),
    path('user/search/', UserSearchAPI.as_view(), name='user-search'),

    path("interests/", AreaOfInterestListCreateAPI.as_view(), name="interest-list-create"),
    path("interests/<int:id>/", AreaOfInterestRetrieveAPI.as_view(), name="interest-retrieve"),
    path("interests/<int:id>/update/", AreaOfInterestUpdateAPI.as_view(), name="interest-update"),
    path("interests/<int:id>/delete/", AreaOfInterestDeleteAPI.as_view(), name="interest-delete"),
    path("user-interests/", UserAreaOfInterestListCreateAPI.as_view(), name="user-interest-list-create"),
    path("user-interests/<int:id>/", UserAreaOfInterestRetrieveAPI.as_view(), name="user-interest-retrieve"),
    path("user-interests/<int:id>/delete/", UserAreaOfInterestDeleteAPI.as_view(), name="user-interest-delete"),

    path('forgot-password/', ForgotPasswordAPI.as_view(), name='forgot_password'),
    path('verify-otp/', VerifyOTPAPI.as_view(), name='verify_otp'),
    path('reset-password/', ResetPasswordAPI.as_view(), name='reset_password'),

    path('device-token/register/', DeviceTokenRegisterAPI.as_view(), name='device-token-register'),
    path('device-token/unregister/', DeviceTokenUnregisterAPI.as_view(), name='device-token-unregister'),
]
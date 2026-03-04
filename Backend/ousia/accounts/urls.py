from django.urls import path

from accounts.views import (
    RegisterView, LoginView, UserPasswordUpdateAPI,
    ProfileResponseAPI, ProfileUpdateAPI, ProfileAdminUpdateAPI,
    AreaOfInterestListCreateAPI, AreaOfInterestRetrieveAPI, AreaOfInterestUpdateAPI, AreaOfInterestDeleteAPI,
    UserAreaOfInterestListCreateAPI, UserAreaOfInterestRetrieveAPI, UserAreaOfInterestDeleteAPI,
)
urlpatterns = [
    path("register/", RegisterView.as_view(), name='register'),
    path("login/", LoginView.as_view(), name='login'),
    path('update_password/', UserPasswordUpdateAPI.as_view(), name='update-password'),
    path('user/profile/', ProfileResponseAPI.as_view(), name='profile-retrieve'),
    path('user/profile_update/', ProfileUpdateAPI.as_view(), name='profile-update'),
    path("user/<int:user_id>/profile/", ProfileAdminUpdateAPI.as_view(), name='profile-update-for-admins'),

    path("interests/", AreaOfInterestListCreateAPI.as_view(), name="interest-list-create"),
    path("interests/<int:id>/", AreaOfInterestRetrieveAPI.as_view(), name="interest-retrieve"),
    path("interests/<int:id>/update/", AreaOfInterestUpdateAPI.as_view(), name="interest-update"),
    path("interests/<int:id>/delete/", AreaOfInterestDeleteAPI.as_view(), name="interest-delete"),
    path("user-interests/", UserAreaOfInterestListCreateAPI.as_view(), name="user-interest-list-create"),
    path("user-interests/<int:id>/", UserAreaOfInterestRetrieveAPI.as_view(), name="user-interest-retrieve"),
    path("user-interests/<int:id>/delete/", UserAreaOfInterestDeleteAPI.as_view(), name="user-interest-delete"),
]
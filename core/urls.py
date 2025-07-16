from django.urls import path

from core.views import (
    EmotionListCreateAPI,
    EmotionRetrieveUpdateDestroy,
    UserEmotionCreateAPIView,
    HashTagListCreateAPI,
    HashTagRetrieveUpdateDestroyAPI,
    PostListCreateAPI,
    PostRetrieveUpdateDeleteAPI,
    MediaDeleteAPI,
    FriendRequestListCreateAPI,
    FriendRequestResponseAPI,
    FriendResponseAPI,
    FriendRequestDeleteAPI,
)

urlpatterns = [
    path('emotion/', EmotionListCreateAPI.as_view(), name='emotion_list_create'),
    path('emotion/<int:pk>/', EmotionRetrieveUpdateDestroy.as_view(), name='emotion_retrieve_update_destroy'),
    path('user_emotion/', UserEmotionCreateAPIView.as_view(), name='user_emotion'),

    path('hashtag/', HashTagListCreateAPI.as_view(), name='hashtag_list_create'),
    path('hashtag/<int:pk>/', HashTagRetrieveUpdateDestroyAPI.as_view(), name='hashtag_retrieve_update_destroy'),

    path('post/', PostListCreateAPI.as_view(), name='post_list_create'),
    path('post/<int:pk>/', PostRetrieveUpdateDeleteAPI.as_view(), name='post_retrieve_update_destroy'),
    path('post/<int:post_id>/media_delete/<int:media_id>/', MediaDeleteAPI.as_view(), name='media_delete'),

    path('friend_request/', FriendRequestListCreateAPI.as_view(), name='friend_request'),
    path('friend_request_response/<int:pk>/', FriendRequestResponseAPI.as_view(), name='friend_request_response'),
    path('friend_request_delete/', FriendRequestDeleteAPI.as_view(), name='friend_request_delete'),
    path('friends/', FriendResponseAPI.as_view(), name='friend_list'),
]

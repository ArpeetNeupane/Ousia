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
    LikeListCreateAPI,
    LikeDeleteAPI,
    CommentListCreateAPI,
    FriendRequestListCreateAPI,
    FriendRequestResponseAPI,
    FriendRequestDeleteAPI,
    FriendListAPI,
    AdminDashboardSummaryAPI,
    AdminDashboardScreenTimeAPI,
    AdminModerationQueueAPI,
    AdminModerationActionAPI,
    SessionStartAPI,
    SessionUpdateAPI,
    SessionEndAPI,
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

    path('likes/', LikeListCreateAPI.as_view(), name='like_list_create'),
    path('like-delete/<int:id>/', LikeDeleteAPI.as_view(), name='like_delete'),
    path('comments/', CommentListCreateAPI.as_view(), name='like_list_create'),

    path('friend_request/', FriendRequestListCreateAPI.as_view(), name='friend_request'),
    path('friend_request_response/<int:pk>/', FriendRequestResponseAPI.as_view(), name='friend_request_response'),
    path('friend_request_delete/<int:pk>/', FriendRequestDeleteAPI.as_view(), name='friend_request_delete'),
    path('friends/', FriendListAPI.as_view(), name='friend_list'),

    path('admin/dashboard/summary/', AdminDashboardSummaryAPI.as_view(), name='admin_dashboard_summary'),
    path('admin/dashboard/screentime/', AdminDashboardScreenTimeAPI.as_view(), name='admin_dashboard_screentime'),
    path('admin/moderation/queue/', AdminModerationQueueAPI.as_view(), name='admin_moderation_queue'),
    path('admin/moderation/action/', AdminModerationActionAPI.as_view(), name='admin_moderation_action'),

    path('session/start/', SessionStartAPI.as_view(), name='session_start'),
    path('session/update/<int:session_id>/', SessionUpdateAPI.as_view(), name='session_update'),
    path('session/end/<int:session_id>/', SessionEndAPI.as_view(), name='session_end'),
]

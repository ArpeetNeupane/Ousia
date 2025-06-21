from django.urls import path

from core.views import HashTagListCreateAPI, HashTagRetrieveUpdateDestroyAPI, PostListCreateAPI, PostRetrieveUpdateDeleteAPI, MediaDeleteAPI

urlpatterns = [
    path('hashtag/', HashTagListCreateAPI.as_view(), name='hashtag_list_create'),
    path('hashtag/<int:pk>/', HashTagRetrieveUpdateDestroyAPI.as_view(), name='hashtag_retrieve_update_destroy'),
    path('post/', PostListCreateAPI.as_view(), name='post_list_create'),
    path('post/<int:pk>/', PostRetrieveUpdateDeleteAPI.as_view(), name='post_retrieve_update_destroy'),
    path('post/<int:post_id>/media_delete/<int:media_id>/', MediaDeleteAPI.as_view(), name='media_delete')
]

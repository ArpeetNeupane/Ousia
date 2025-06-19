from django.urls import path

from core.views import *

urlpatterns = [
    path('hashtag/', HashTagListCreateAPI.as_view(), name='hashtag_list_create'),
    path('hashtag/<int:pk>/', HashTagRetrieveUpdateDestroy.as_view(), name='hashtag_retrieve_update_destroy')
]

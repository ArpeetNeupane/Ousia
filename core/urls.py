from django.urls import path

from core.views import *

urlpatterns = [
    path('hashtag/', HashTagListCreateAPI.as_view(), name='hashtag'),
]

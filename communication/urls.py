from django.urls import path

from communication.views import (
    ConversationListAPI, 
    ConversationCreateAPI, 
    ConversationRetrieveAPI, 
    ConversationUpdateAPI, 
    ConversationSoftDBDeleteAPI,
    ConversationSoftDeleteForUserAPI
)

urlpatterns = [
    path('conversation-list/', ConversationListAPI.as_view(), name='conversation_list'),
    path('conversation-create/', ConversationCreateAPI.as_view(), name='conversation_create'),
    path('conversation-retrieve/<uuid:id>/', ConversationRetrieveAPI.as_view(), name='conversation_retrieve'),
    path('conversation-update/<uuid:id>/', ConversationUpdateAPI.as_view(), name='conversation_update'),
    path('conversation-delete/<uuid:id>/', ConversationSoftDBDeleteAPI.as_view(), name='conversation_soft_db_delete'),
    path('conversation-soft-delete-for-user/<uuid:id>/', ConversationSoftDeleteForUserAPI.as_view(), name='conversation_soft_delete_for_user'),
]
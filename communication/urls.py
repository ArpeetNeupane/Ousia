from django.urls import path

from communication.views import ConversationListAPI, ConversationCreateAPI, ConversationRetrieveAPI, ConversationUpdateAPI, ConversationDeleteAPI

urlpatterns = [
    path('conversation-list/', ConversationListAPI.as_view(), name='conversation_list'),
    path('conversation-create/', ConversationCreateAPI.as_view(), name='conversation_create'),
    path('conversation-retrieve/<uuid:id>/', ConversationRetrieveAPI.as_view(), name='conversation_retrieve'),
    path('conversation-update/<uuid:id>/', ConversationUpdateAPI.as_view(), name='conversation_update'),
    path('conversation-delete/<uuid:id>/', ConversationDeleteAPI.as_view(), name='conversation_delete'),
]
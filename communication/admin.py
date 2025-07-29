from django.contrib import admin

from communication.models import Conversation

@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ['id', 'is_group', 'group_name', 'group_admin', 'is_deleted', 'updated_at']
    search_fields = ['group_name', 'group_admin__username']
    list_filter = ['is_group', 'is_deleted']
    readonly_fields = ['id', 'created_at', 'updated_at']
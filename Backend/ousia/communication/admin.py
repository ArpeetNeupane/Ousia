from django.contrib import admin

from communication.models import Conversation, ConversationParticipant, Message

class ConversationParticipantInline(admin.TabularInline):
    model = ConversationParticipant
    extra = 1  #number of blank forms shown by default

@admin.register(Conversation)
class ConversationAdmin(admin.ModelAdmin):
    list_display = ['id', 'is_group', 'group_name', 'group_admin', 'is_deleted', 'updated_at']
    search_fields = ['group_name', 'group_admin__username']
    list_filter = ['is_group', 'is_deleted']
    readonly_fields = ['id', 'created_at', 'updated_at', 'is_deleted']
    inlines = [ConversationParticipantInline]

@admin.register(ConversationParticipant)
class ConversationParticipantAdmin(admin.ModelAdmin):
    list_display = ['id', 'conversation', 'user']
    search_fields = ['user__username', 'conversation__group_name']

@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = ['id', 'conversation', 'sender', 'is_edited', 'created_at', 'updated_at', 'is_deleted']
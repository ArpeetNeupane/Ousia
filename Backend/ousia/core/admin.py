from django.contrib import admin

from core.models import (
    Emotion,
    UserEmotion,
    HashTag,
    Post,
    MediaUpload,
    PostHashTag,
    FriendRequest,
    Friend,
    UserSession
)


@admin.register(Emotion)
class EmotionAdmin(admin.ModelAdmin):
    list_display = ['emotion_emoji_name', 'emotion_public_id', 'upload_order', 'created_at']
    search_fields = ['emotion_emoji_name']
    ordering = ['-upload_order']


@admin.register(UserEmotion)
class UserEmotionAdmin(admin.ModelAdmin):
    list_display = ['user', 'emotion', 'noted_at']
    list_filter = ['emotion']
    search_fields = ['user__username', 'emotion__emotion_emoji_name']
    ordering = ['-noted_at']


@admin.register(HashTag)
class HashTagAdmin(admin.ModelAdmin):
    list_display = ['name', 'created_by', 'created_at']
    search_fields = ['name', 'created_by__username']
    ordering = ['name']


class PostHashTagInline(admin.TabularInline):
    model = PostHashTag
    extra = 1  #how many blank forms to show
    autocomplete_fields = ['hashtag']


@admin.register(Post)
class PostAdmin(admin.ModelAdmin):
    list_display = ['id', 'posted_by', 'caption', 'visibility', 'created_at', 'is_deleted']
    list_filter = ['visibility', 'is_deleted', 'created_at']
    search_fields = ['caption', 'posted_by__username']
    ordering = ['-created_at']
    inlines = [PostHashTagInline]


@admin.register(MediaUpload)
class MediaUploadAdmin(admin.ModelAdmin):
    list_display = ['post', 'public_id', 'is_video', 'upload_order', 'created_at']
    ordering = ['upload_order']


@admin.register(FriendRequest)
class FriendRequestAdmin(admin.ModelAdmin):
    list_display = ['from_user', 'to_user', 'status', 'created_at', 'responded_at']
    list_filter = ['status', 'created_at']
    search_fields = ['from_user__username', 'to_user__username']


@admin.register(Friend)
class FriendAdmin(admin.ModelAdmin):
    list_display = ['user1', 'user2', 'created_at', 'accepted_at', 'blocked_by']
    list_filter = ['blocked_by', 'created_at']
    search_fields = ['user1__username', 'user2__username']

@admin.register(UserSession)
class UserSessionAdmin(admin.ModelAdmin):
    list_display = ['id', 'user', 'start_time', 'end_time', 'duration_seconds']
    list_filter = ['start_time', 'end_time']
    search_fields = ['user__username', 'session_id']
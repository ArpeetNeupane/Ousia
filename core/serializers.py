from core.models import CurrentEmotion, HashTag, Post, MediaUpload, PostHashTag, Like, Comment
from core.mixins import MediaValidationMixin
from core.service import PostCreateService, PostUpdateService

from rest_framework import serializers
from rest_framework.exceptions import ValidationError

import cloudinary, cloudinary.uploader, mimetypes, os
from cloudinary.utils import cloudinary_url

from django.db import transaction

class HashTagRetrieveCreateUpdateSerializer(serializers.ModelSerializer):
    created_by_username = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = HashTag
        fields = ['id', 'name', 'created_by', 'created_by_username', 'created_at']
        read_only_fields = ['id', 'created_by', 'created_by_username', 'created_at']

    def get_created_by_username(self, obj):
        return obj.created_by.username if obj.created_by else None

    def validate_name(self, value): #when using validate_fieldname, the method gets raw field value by itself. data.get isnt required.
        #removing spaces
        value_no_spaces = value.replace(" ", "")
        value = value_no_spaces.strip()

        if not value.startswith('#'):
            raise serializers.ValidationError(
                {"hashtag": "A hashtag must start with a #."}
            )

        #making sure something remains after #, when user inputs something like "# "
        if len(value_no_spaces) == 1:
            raise serializers.ValidationError("Hashtag cannot be just #.")

        return value

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)

    def update(self, instance, validated_data):
        for attrs, value in validated_data.items():
            setattr(instance, attrs, value)
        instance.save()
        return instance


class MediaUploadSerializer(serializers.ModelSerializer):
    media_url = serializers.SerializerMethodField(read_only=True)

    class Meta:
        model = MediaUpload
        fields = ['id', 'public_id', 'is_video', 'upload_order', 'media_url']
        read_only_fields = ['id', 'public_id', 'is_video', 'upload_order', 'media_url']

    def get_media_url(self, obj):
        #returning no url if public id isn't found
        if not obj.public_id:
            return None

        if obj.is_video:
            url, _ = cloudinary_url(obj.public_id, resource_type="video", secure=True)
        else:
            url, _ = cloudinary_url(obj.public_id, resource_type="image", secure=True)
        return url


class PostResponseCreateSerializer(MediaValidationMixin, serializers.ModelSerializer):
    posted_by_username = serializers.SerializerMethodField(read_only=True)
    visibility_label = serializers.SerializerMethodField()
    media_files = MediaUploadSerializer(source='post_media', many=True, read_only=True)
    media = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        write_only=True,
        help_text="Upload media files for the post"
    )
    type_of_post = serializers.CharField(required=False, help_text="Comma-separated hashtag names")
    class Meta:
        model = Post
        fields = [
            'id', 'caption', 'visibility_label', 'created_at', 'updated_at', 'posted_by', 'posted_by_username',
            'type_of_post', 'media', 'media_files', 'post_like_count', 'post_comment_count'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'posted_by', 'posted_by_username', 'post_like_count', 'post_comment_count', 'media_url']

    def get_posted_by_username(self, obj):
        return obj.posted_by.username if obj.posted_by else None

    def get_visibility_label(self, obj):
        return obj.get_visibility_display()

    def create(self, validated_data):
        request = self.context['request']
        media_files = validated_data.pop('media', [])
        hashtags_string = validated_data.pop('type_of_post', '')

        return PostCreateService.create_post_with_media_and_hashtags(
            user=request.user,
            validated_data=validated_data,
            media_files=media_files,
            hashtags_string=hashtags_string
        )

    def to_representation(self, instance):
        data = super().to_representation(instance)
        #converting hashtags back to comma-separated string for consistency
        hashtags = instance.type_of_post.all()
        data['type_of_post'] = ','.join([tag.name for tag in hashtags])
        return data


class PostResponseUpdateSerializer(MediaValidationMixin, serializers.ModelSerializer):
    type_of_post = serializers.CharField(
        required=False,
        help_text="Comma-separated hashtag names"
    )
    media = serializers.ListField(
        child=serializers.FileField(),
        required=False,
        write_only=True,
        help_text="Upload media files. Replaces existing media."
    )
    media_files = MediaUploadSerializer(source='post_media', many=True, read_only=True)

    class Meta:
        model = Post
        fields = [
            'id', 'caption', 'visibility', 'type_of_post', 'media', 'media_files',
            'created_at', 'updated_at', 'post_like_count', 'post_comment_count'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'post_like_count', 'post_comment_count', 'media_files']

    def update(self, instance, validated_data):
        request = self.context['request']
        hashtags_string = validated_data.pop('type_of_post', None)
        media_files = validated_data.pop('media', None)

        return PostUpdateService.update_post_with_media_and_hashtags(
            instance=instance,
            validated_data=validated_data,
            media_files=media_files,
            hashtags_string=hashtags_string
        )

    def to_representation(self, instance):
        data = super().to_representation(instance)
        #returning hashtags as comma-separated names
        hashtags = instance.type_of_post.all()
        data['type_of_post'] = ','.join([tag.name for tag in hashtags])
        return data


class LikeRetrieveCreateSerializer(serializers.ModelSerializer):
    pass


class CommentRetrieveCreateSerializer(serializers.ModelSerializer):
    pass


class CommentUpdateSerializer(serializers.ModelSerializer):
    pass
from core.models import *
from core.mixins import MediaValidationMixin

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
            'id', 'caption', 'visibility', 'created_at', 'posted_by', 'posted_by_username',
            'type_of_post', 'media', 'media_files', 'post_like_count', 'post_comment_count'
        ]
        read_only_fields = ['id', 'created_at', 'posted_by', 'posted_by_username', 'post_like_count', 'post_comment_count', 'media_url']

    def get_posted_by_username(self, obj):
        return obj.posted_by.username if obj.posted_by else None

    def create(self, validated_data):
        request = self.context['request']
        media_files = validated_data.pop('media', [])
        hashtags_string = validated_data.pop('type_of_post', '')

        try:
            with transaction.atomic():
                #first, creating a post object and then linking the many-to-many hashtag field to it
                validated_data['posted_by'] = request.user
                post = super().create(validated_data)

                if hashtags_string:
                    hashtag_names = [tag.strip() for tag in hashtags_string.split(',') if tag.strip()]
                    final_hashtags = []

                    for name in hashtag_names:
                        try:
                            hashtag = HashTag.objects.get(name=name)
                            final_hashtags.append(hashtag)
                        except HashTag.DoesNotExist:
                            raise serializers.ValidationError(
                                {"type_of_post:" f"Hashtag '{name}' doesn't exist."}
                            )

                    if final_hashtags:
                        post.type_of_post.set(final_hashtags)

                if media_files:
                    for index, media_file in enumerate(media_files):
                        uploaded = cloudinary.uploader.upload(media_file, resource_type='auto')
                        MediaUpload.objects.create(
                            post=post,
                            public_id=uploaded['public_id'],
                            is_video=uploaded['resource_type'] == 'video',
                            upload_order=index
                        )
                post.refresh_from_db()
                return post

        except Exception as e:
            print(str(e))
            raise serializers.ValidationError("An error occured during creation of Post. Try again later.")

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

        #updating caption and visibility
        instance.caption = validated_data.get('caption', instance.caption) #caption is updated value, instance.caption is fallback to current
        instance.visibility = validated_data.get('visibility', instance.visibility)
        instance.save()

        #updating hashtags
        if hashtags_string is not None:
            hashtag_names = [tag.strip() for tag in hashtags_string.split(',') if tag.strip()]
            hashtags = HashTag.objects.filter(name__in=hashtag_names)

            if hashtags.count() != len(set(hashtag_names)):
                found_names = set(hashtags.values_list('name', flat=True))
                missing = set(hashtag_names) - found_names
                raise serializers.ValidationError(
                    {"type_of_post": f"These hashtags do not exist: {', '.join(missing)}"}
                )
            instance.type_of_post.set(hashtags)

        #updating media if new files provided
        if media_files:
            #deleting old Cloudinary files and db records
            for old_media in instance.post_media.all():
                if old_media.public_id:
                    try:
                        cloudinary.uploader.destroy(old_media.public_id, resource_type='video' if old_media.is_video else 'image')
                    except Exception as e:
                        print(f"Cloudinary deletion failed for {old_media.public_id}: {e}")
                old_media.delete()

            #uploading new media files
            for index, media_file in enumerate(media_files):
                uploaded = cloudinary.uploader.upload(media_file, resource_type='auto')
                MediaUpload.objects.create(
                    post=instance,
                    public_id=uploaded['public_id'],
                    is_video=uploaded['resource_type'] == 'video',
                    upload_order=index
                )

        instance.refresh_from_db()
        return instance

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
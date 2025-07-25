from core import models
from core.models import Emotion, UserEmotion, HashTag, Post, MediaUpload, PostHashTag, Like, Comment, FriendRequest, Friend
from core.mixins import MediaValidationMixin
from core.service import PostCreateService, PostUpdateService
from accounts.models import User

from rest_framework import serializers
from rest_framework.exceptions import ValidationError

import cloudinary
from cloudinary.utils import cloudinary_url

from django.utils import timezone
from django.db.models import Q


class EmotionCreateRetrieveUpdateSerializer(serializers.ModelSerializer):
    emotion_image = serializers.ImageField(write_only=True)
    emotion_url = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = Emotion
        fields = ['id', 'emotion_emoji_name', 'emotion_public_id', 'emotion_url', 'emotion_image', 'created_at', 'updated_at']
        read_only_fields = ['id', 'emotion_public_id', 'emotion_url', 'created_at', 'updated_at']

    def get_emotion_url(self, obj):
        try:
            public_id = getattr(obj, "emotion_public_id", None)
            #returning no url if public id isn't found
            if not public_id:
                return None

            url, _ = cloudinary_url(public_id, resource_type="image", secure=True)
            return url
        except Exception:
            return None

    def validate(self, data):
        emotion_name = data.get('emotion_emoji_name')
        if emotion_name:
            if Emotion.objects.filter(emotion_emoji_name=emotion_name).exists():
                raise serializers.ValidationError(
                    {"emotion_name": "An emotion with this name already exists."}
                )
            if len(emotion_name) > 20:
                raise serializers.ValidationError(
                    {"emotion_name": "Emotion's name cannot be longer than 20."}
                )
        return data

    def create(self, validated_data):
        emotion_image = validated_data.pop("emotion_image", None)
        if emotion_image:
            upload_result = cloudinary.uploader.upload(emotion_image, resource_type="image")
            validated_data["emotion_public_id"] = upload_result.get("public_id")
        return super().create(validated_data)

    def update(self, instance, validated_data):
        emotion_image = validated_data.pop("emotion_image", None)
        if emotion_image:
            upload_result = cloudinary.uploader.upload(emotion_image, resource_type="image")
            instance.emotion_public_id = upload_result.get("public_id")

        #updating other fields
        for attr, value in validated_data.items():
            setattr(instance, attr, value)

        instance.save()
        return instance


class UserEmotionSerializer(serializers.ModelSerializer):
    emotion_name = serializers.CharField(source='emotion.emotion_emoji_name', read_only=True)
    emotion_id = serializers.PrimaryKeyRelatedField(
        queryset=Emotion.objects.all(), source='emotion', write_only=True
    )

    class Meta:
        model = UserEmotion
        fields = ['id', 'emotion_id', 'emotion_name', 'noted_at']
        read_only_fields = ['id', 'emotion_name', 'noted_at']


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


class PostUpdateSerializer(MediaValidationMixin, serializers.ModelSerializer):
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


class FriendRequestCreateSerializer(serializers.ModelSerializer):
    # not Charfield like model to ensure only valid choices are accepted when serializing or deserializing data
    status = serializers.ChoiceField(choices=FriendRequest.RequestStatusEnum.choices, read_only=True)
    from_user = serializers.SlugRelatedField(read_only=True, slug_field='username')
    to_user = serializers.SlugRelatedField(read_only=True, slug_field='username')
    to_username = serializers.CharField(write_only=True)
    class Meta:
        model = FriendRequest
        fields = ['id', 'from_user', 'to_username', 'to_user', 'status', 'created_at', 'responded_at']
        read_only_fields = ['id', 'from_user', 'to_user', 'created_at', 'responded_at']

    def validate_to_username(self, username):
        try:
            return User.objects.get(username=username)
        except User.DoesNotExist:
            raise serializers.ValidationError("User with this username does not exist.")

    def validate(self, data):
        request_user = self.context['request'].user
        to_user = data.get('to_username') #could go with data['to_username'] as it's required and we're sure it exists

        if not to_user:
            raise serializers.ValidationError(
                {"to_username": "This field is required."}
            )

        #blocking friend request to self
        if request_user == to_user:
            raise serializers.ValidationError(
                {"friend_request": "You cannot send a friend request to yourself."}
            )

        #checking if friend request already exists between two users
        if FriendRequest.objects.filter(
            from_user=request_user,
            to_user=to_user,
            status=FriendRequest.RequestStatusEnum.PENDING
        ).exists():
            raise serializers.ValidationError(
                {"friend_request": f"You have already sent a friend request to {to_user}"}
            )
        if FriendRequest.objects.filter(
            from_user=to_user,
            to_user=request_user,
            status=FriendRequest.RequestStatusEnum.PENDING
        ).exists():
            raise serializers.ValidationError(
                {"friend_request": f"You already have a pending friend request from {to_user}"}
            )

        #checking if the users are already friends
        if Friend.objects.filter(
            Q(user1=request_user, user2=to_user) |
            Q(user1=to_user, user2=request_user)
        ).exists():
            raise serializers.ValidationError(
                {"friend_request": f"You are already friends with {to_user}"}
            )

        data['to_user'] = to_user
        data.pop('to_username')
        return data

    def create(self, validated_data):
        from_user = self.context['request'].user
        to_user = validated_data['to_user']
        return FriendRequest.objects.create(from_user=from_user, to_user=to_user)


class FriendRequestResponseSerializer(serializers.ModelSerializer):
    status = serializers.ChoiceField(choices=[
        FriendRequest.RequestStatusEnum.ACCEPTED,
        FriendRequest.RequestStatusEnum.REJECTED
    ])

    class Meta:
        model = FriendRequest
        fields = ['status']

    def validate(self, data):
        request = self.context['request']
        friend_request = self.instance

        if request.user != friend_request.to_user:
            raise serializers.ValidationError(
                {"accept_request": f"You are not allowed to respond to this friend request as you weren't the one to initiate it."}
            )

        if friend_request.status != FriendRequest.RequestStatusEnum.PENDING:
            raise serializers.ValidationError(
                {"accept_request": f"This friend request has already been responded to."}
            )

        return data

    def update(self, instance, validated_data):
        status = validated_data.get('status')

        if not status:
            raise serializers.ValidationError({"status": "This field is required."})

        instance.status = validated_data['status']
        instance.responded_at = timezone.now()

        #if request is accepted, creating a new Friend object
        if instance.status == FriendRequest.RequestStatusEnum.ACCEPTED:
            from_user = instance.from_user
            to_user = instance.to_user

            #preventing duplicate friendships
            if Friend.objects.filter(
                Q(user1=to_user, user2=from_user) |
                Q(user1=from_user, user2=to_user)
            ).exists():
                Friend.objects.create(user1=from_user, user2=to_user)
        instance.save()
        return instance


class FriendResponseSerializer(serializers.ModelSerializer):
    friend = serializers.SerializerMethodField()
    class Meta:
        model = Friend
        fields = ['id', 'friend', 'accepted_at', 'is_blocked']
        read_only_fields = ['id', 'friend', 'accepted_at', 'is_blocked']

    def get_friend(self, obj):
        #returning the other user in the friendship
        request_user = self.context['request'].user
        if obj.user1 == request_user:
            return obj.user2.username
        else:
            return obj.user1.username
from core import models
from core.models import (
    Emotion,
    UserEmotion,
    HashTag,
    Post,
    MediaUpload,
    PostHashTag,
    Like,
    Comment,
    FriendRequest,
    Friend
)
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
    #not Charfield like model to ensure only valid choices are accepted when serializing or deserializing data
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
        to_user = data['to_username']

        if request_user == to_user:
            raise serializers.ValidationError({
                "friend_request": "You cannot send a friend request to yourself."
            })

        #checking if users are already friends
        if Friend.objects.filter(
            Q(user1=request_user, user2=to_user) | Q(user1=to_user, user2=request_user)
        ).exists():
            raise serializers.ValidationError({
                "friend_request": f"You are already friends with {to_user}."
            })

        #checking for duplicate or cross friend requests
        pending_requests = FriendRequest.objects.filter(
            Q(from_user=request_user, to_user=to_user) |
            Q(from_user=to_user, to_user=request_user)
        ).filter(status=FriendRequest.RequestStatusEnum.PENDING)

        if pending_requests.exists():
            #determining direction of the request to show better message
            if pending_requests.filter(from_user=request_user).exists():
                message = f"You have already sent a friend request to {to_user}."
            else:
                message = f"You already have a pending friend request from {to_user}."
            raise serializers.ValidationError({"friend_request": message})

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
        FriendRequest.RequestStatusEnum.REJECTED,
        FriendRequest.RequestStatusEnum.DELETED
    ])

    class Meta:
        model = FriendRequest
        fields = ['status']

    def validate(self, data):
        request = self.context['request']
        user = request.user
        new_status = data.get('status')

        if self.instance.status != FriendRequest.RequestStatusEnum.PENDING:
            raise serializers.ValidationError(
                {"accept_request": f"This friend request has already been responded to."}
            )

        #if receiver is responding (accept/reject)
        if user == self.instance.to_user: #self means current serializer, self.instance is current serializer's model
            if new_status not in [FriendRequest.RequestStatusEnum.ACCEPTED, FriendRequest.RequestStatusEnum.REJECTED]:
                raise serializers.ValidationError("You can only accept or reject the request.")

        #if sender is cancelling the request
        elif user == self.instance.from_user:
            if new_status != FriendRequest.RequestStatusEnum.DELETED:
                raise serializers.ValidationError("You can only cancel (delete) the request you sent.") #only allowing the sender to delete the request, no other choice

        else:
            if not user.is_staff:
                raise serializers.ValidationError("You are not allowed to update this friend request.")

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

            #sorting users in asc order of id to ensure canonical order in db level as well
            user1, user2 = sorted([from_user, to_user], key=lambda u: u.id)
            if not Friend.objects.filter(
                Q(user1=user1, user2=user2)
            ).exists():
                Friend.objects.create(user1=user1, user2=user2)
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
        friend = obj.user2 if obj.user1 == request_user else obj.user1
        return {"id": friend.id, "username": friend.username}

class FriendSerializer(serializers.ModelSerializer):
    user1 = serializers.PrimaryKeyRelatedField(queryset=User.objects.all())
    user2 = serializers.PrimaryKeyRelatedField(queryset=User.objects.all())

    class Meta:
        model = Friend
        fields = ['id', 'user1', 'user2', 'created_at', 'accepted_at', 'is_blocked']
        read_only_fields = ['id', 'created_at', 'accepted_at']

    def validate(self, data):
        user1 = data.get('user1')
        user2 = data.get('user2')

        #blocking self-friendship
        if user1 == user2:
            raise serializers.ValidationError("You cannot create a friendship with yourself.")

        # This is not required now as there is direct UniqueCOnstraint + db level validation for friendship check
        # And, the errors will hit exception handler and show a 400 properly
        # #ordering consistently to match DB UniqueConstraint
        # user_pair = sorted([user1.id, user2.id])
        # if Friend.objects.filter(
        #     Q(user1_id=user_pair[0], user2_id=user_pair[1]) |
        #     Q(user1_id=user_pair[1], user2_id=user_pair[0])
        # ).exists():
        #     raise serializers.ValidationError("Friendship already exists between these users.")
        # return data
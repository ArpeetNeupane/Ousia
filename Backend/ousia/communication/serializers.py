from django.db import transaction

from accounts.serializers import UserSerializer

from accounts.models import User, Profile
from accounts.serializers import ProfilePictureSerializer
from communication.service import check_for_existing_one_on_one_conversation
from communication.models import Conversation, Message

from rest_framework import serializers


class ConversationResponseSerializer(serializers.ModelSerializer):
    participants = UserSerializer(many=True, read_only=True)
    pfp_info = serializers.SerializerMethodField()
    class Meta:
        model=Conversation
        fields = ['id', 'participants', 'pfp_info', 'is_group', 'group_name', 'group_admin', 'created_at', 'updated_at', 'is_deleted']
        read_only_fields = ['id', 'is_group', 'group_admin', 'created_at', 'updated_at', 'is_deleted']

    def get_pfp_info(self, obj):
        current_user = self.context['request'].user
        other_participants = obj.participants.exclude(id=current_user.id)
        profiles = Profile.objects.select_related('user').filter(
            user__in=other_participants
        )
        return ProfilePictureSerializer(profiles, many=True).data


class ConversationCreateSerializer(serializers.ModelSerializer):
    participants = serializers.PrimaryKeyRelatedField(
        queryset=User.objects.all(),
        many=True,
        write_only=True
    )
    participants_detail = UserSerializer(many=True, read_only=True, source='participants')

    class Meta:
        model=Conversation
        fields = ['id', 'participants', 'participants_detail', 'is_group', 'group_name', 'group_admin', 'created_at', 'updated_at', 'is_deleted']
        read_only_fields = ['id', 'participants_detail', 'group_admin', 'created_at', 'updated_at', 'is_deleted']

    def validate(self, data):
        request_user = self.context['request'].user
        is_group = data.get('is_group')
        group_name = data.get('group_name')
        participants = data.get('participants', [])
        all_users = list(participants) + [request_user]

        if request_user in participants:
            raise serializers.ValidationError("You cannot add yourself as a participant.")

        if not participants:
            raise serializers.ValidationError("At least one participant is required.")

        #if 1-on-1 conversation:
        if not is_group:
            if len(participants) + 1 > 2:  #+1 for request.user who will be added automatically
                raise serializers.ValidationError("1-on-1 conversations cannot have more than 2 participants. Please provide group name if there are multiple participants.")

            if group_name:
                raise serializers.ValidationError("Group name cannot be set for 1-on-1 conversations.")

            #preventing duplicate conversation for the same 2 users, the view will catch this and return the already existing convo id
            if len(all_users) == 2:
                existing_convo = check_for_existing_one_on_one_conversation(all_users)
                if existing_convo:
                    self.existing_conversation = existing_convo
                    return data

        #if group conversation:
        if is_group:
            if not group_name:
                raise serializers.ValidationError("Group name is required for group conversations.")
            if len(participants) + 1 <= 2:
                raise serializers.ValidationError("A group chat must have more than 2 participants.")

        return data

    def create(self, validated_data):
        users = validated_data.pop('participants')
        request_user = self.context['request'].user

        with transaction.atomic():
            #creating conversation
            conversation = Conversation.objects.create(
                is_group=len(users) > 1,
                group_name=validated_data.get('group_name', None),
            )
            conversation.participants.set(users + [request_user])
            conversation.make_group_admin(request_user) #using model method
            conversation.save()
        return conversation


class ConversationUpdateSerializer(serializers.ModelSerializer):
    group_name = serializers.CharField(required=False)

    class Meta:
        model=Conversation
        fields = ['id', 'group_name', 'updated_at', 'is_deleted']
        read_only_fields = ['id', 'updated_at', 'is_deleted']

    def validate(self, data):
        is_group = getattr(self.instance, 'is_group', None)
        group_name = data.get('group_name')

        if not is_group and group_name:
            raise serializers.ValidationError("A 1-on-1 conversation cannot have a group name.")
        if group_name is not None:
            group_name = group_name.strip()
        if not group_name:
            raise serializers.ValidationError("Group name cannot be empty.")
        data['group_name'] = group_name
        return data

    def update(self, instance, validated_data):
        with transaction.atomic():
            if 'group_name' in validated_data:
                instance.group_name = validated_data['group_name']
                instance.save()
        return instance

class MessageResponseSerializer(serializers.ModelSerializer):
    conversation_name = serializers.SerializerMethodField(read_only=True)
    sender_username = serializers.CharField(source='sender.username', read_only=True)

    class Meta:
        model=Message
        fields = [
            'id', 'conversation', 'conversation_name', 'message_type', 'sender', 'sender_username', 'content',
            'created_at', 'updated_at', 'is_edited', 'is_deleted'
        ]
        read_only_fields = [
            'id', 'message_type', 'sender', 'created_at',
            'updated_at', 'is_edited', 'is_deleted'
        ]

    def get_conversation_name(self, obj):
        convo = obj.conversation
        if convo.is_group:
            return convo.group_name
        other = convo.get_other_participant()
        return other.username if other else None #so that we dont get AttributeError


class MessageCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model=Message
        fields = [
            'id', 'conversation', 'message_type', 'sender', 'content',
            'created_at', 'updated_at', 'is_edited', 'is_deleted'
        ]
        read_only_fields = [
            'id', 'message_type', 'sender', 'created_at',
            'updated_at', 'is_edited', 'is_deleted'
        ]


class MessageUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model=Message
        fields = [
            'id', 'conversation', 'message_type', 'sender', 'content', 'file_attachment_public_url',
            'reply_to', 'created_at', 'updated_at', 'is_edited', 'is_deleted'
        ]
        read_only_fields = [
            'id', 'message_type', 'sender', 'file_attachment_public_url',
            'created_at', 'updated_at', 'is_edited', 'is_deleted'
        ]
from accounts.models import User

from communication.models import Conversation, ConversationParticipant, Message
from communication.serializers import (
    ConversationResponseSerializer,
    ConversationCreateSerializer,
    ConversationUpdateSerializer,
    MessageResponseSerializer
)
from communication.paginations import CommunicationPagination
from communication.permissions import BelongsToConversation, IsAdminOfConversation
from communication.filters import ConversationFilter
from myproject.utils import api_response

from rest_framework import generics, status
from rest_framework.views import APIView
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.exceptions import ValidationError, PermissionDenied

from django_filters.rest_framework import DjangoFilterBackend

from drf_yasg import openapi
from drf_yasg.utils import swagger_auto_schema

from django.shortcuts import get_object_or_404
from django.db import transaction


class ConversationListAPI(generics.ListAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, BelongsToConversation]
    serializer_class = ConversationResponseSerializer
    pagination_class = CommunicationPagination
    filter_backends = [DjangoFilterBackend]
    filterset_class = ConversationFilter

    def get_queryset(self):
        user = self.request.user
        #finding conversations (doesn't matter if deleted by a user or not - returning all)
        participant_qs = ConversationParticipant.objects.filter(user=user)#was deleted_for_user=False but removed it so that if they search fot a deleted convo to chat again, i'll be retrieved
        #getting list of the convo ids
        conversation_ids = participant_qs.values_list('conversation_id', flat=True)
        #flat=True gives a plain list instead of a list of tuples.
        queryset = Conversation.objects.filter(id__in=conversation_ids)

        username = self.request.query_params.get("username")
        if username:
            queryset = queryset.filter(participants__username__icontains=username)#.exclude(participants=user)
        return queryset

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        return api_response(
            is_success=True,
            result={
                "message": "Successfully retrieved conversation.",
                "data": response.data
            },
            status_code=status.HTTP_200_OK
        )

    @swagger_auto_schema(
        operation_description="Retrieve the list of all conversations.",
        responses={
            200: openapi.Response(
                description="Successfully retrieved paginated data.",
                schema=ConversationResponseSerializer(many=True),
            ),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="You do not have permission to perform this action."),
            500: openapi.Response(description="Internal server error.")
        },
        tags=["Conversation"]
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)


class ConversationCreateAPI(generics.CreateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = ConversationCreateSerializer
    pagination_class = CommunicationPagination

    def get_queryset(self):
        user = self.request.user
        conversation_ids = ConversationParticipant.objects.filter(
            user=user,
            deleted_for_user=False
        ).values_list('conversation_id', flat=True)
        return Conversation.objects.filter(id__in=conversation_ids)

    def perform_create(self, serializer):
        serializer.save()

    def create(self, request, *args, **kwargs):
        # try:
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        #checking if the serializer has caught an existing conversation
        if hasattr(serializer, 'existing_conversation'):
            existing_convo = serializer.existing_conversation

            #checking if it was soft-deleted for current user
            participant_qs = ConversationParticipant.objects.filter(
                conversation=existing_convo,
                user=request.user
            )

            was_deleted = participant_qs.filter(deleted_for_user=True).exists()
            if was_deleted:
                #un-soft deleting
                participant_qs.update(deleted_for_user=False)
                message = "Conversation already exists. Undeleted for you."
            else:
                message = "Conversation already exists."

            convo_serializer = self.get_serializer(existing_convo)
            return api_response(
                is_success=True,
                result={
                    "message": message,
                    "data": convo_serializer.data
                },
                status_code=status.HTTP_200_OK
            )
        else:
            self.perform_create(serializer)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully created conversation.",
                    "data": serializer.data
                },
                status_code=status.HTTP_201_CREATED
            )
        # except ValidationError as ve:
        #     return api_response(
        #         is_success=False,
        #         error_message=ve.detail,
        #         status_code=status.HTTP_400_BAD_REQUEST
        #     )
        # except Exception as e:
        #     return api_response(
        #         is_success=False,
        #         error_message=str(e),
        #         status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        #     )

    @swagger_auto_schema(
        operation_description="Create a conversation. The authenticated user will automatically become the group admin if s/he created the group and be added as a participant.",
        responses={
            201: openapi.Response(
                description="Successfully created conversation.",
                schema=ConversationCreateSerializer
            ),
            400: openapi.Response(description="Validation error."),
            403: openapi.Response(description="Permission denied"),
            500: openapi.Response(description="Internal server error."),
        },
        tags=["Conversation"],
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)


class ConversationRetrieveAPI(generics.RetrieveAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, BelongsToConversation]
    serializer_class = ConversationResponseSerializer
    pagination_class = CommunicationPagination
    lookup_field = 'id'

    def get_queryset(self):
        user = self.request.user
        conversation_ids = ConversationParticipant.objects.filter(
            user=user,
            deleted_for_user=False
        ).values_list('conversation_id', flat=True)
        return Conversation.objects.filter(id__in=conversation_ids)

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(self, request, *args, **kwargs)
        return api_response(
            is_success=True,
            result={
                "message": "Successfully retrieved conversation.",
                "data": response.data
            },
            status_code=status.HTTP_200_OK
        )

    @swagger_auto_schema(
        operation_description="Retrieve the list of a single conversations.",
        responses={
            200: openapi.Response(
                description="Successfully retrieved paginated data.",
                schema=ConversationResponseSerializer(),
            ),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="You do not have permission to perform this action."),
            500: openapi.Response(description="Internal server error.")
        },
        tags=["Conversation"]
    )
    def get(self, request, *args, **kwargs):
        return self.retrieve(request, *args, **kwargs)


class ConversationUpdateAPI(generics.UpdateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminOfConversation]
    serializer_class = ConversationUpdateSerializer
    http_method_names = ["patch"]
    lookup_field = 'id'

    def get_queryset(self):
        user = self.request.user
        #ensuring user can only update active conversations
        conversation_ids = ConversationParticipant.objects.filter(
            user=user,
            deleted_for_user=False
        ).values_list('conversation_id', flat=True)
        return Conversation.objects.filter(id__in=conversation_ids, is_group=True)

    def partial_update(self, request, *args, **kwargs):
    #     try:
        response = super().partial_update(request, *args, **kwargs)
        return api_response(
            is_success=True,
            result={
                "message": "Updated conversation successfully.",
                "data": response.data
            },
            status_code=status.HTTP_200_OK
        )
        # except ValidationError as ve:
        #     return api_response(
        #         is_success=False,
        #         error_message=ve.detail,
        #         status_code=status.HTTP_400_BAD_REQUEST
        #     )
        # except Exception as e:
        #     return api_response(
        #         is_success=False,
        #         error_message=str(e),
        #         status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        #     )

    @swagger_auto_schema(
        operation_description="Partially update a conversation. Used for updating a group's name.",
        request_body=ConversationUpdateSerializer,
        responses={
            200: openapi.Response(
                description="Conversation updated successfully.",
                schema=ConversationUpdateSerializer()
            ),
            400: "Validation Error",
            404: "Not Found.",
            403: "Permission Error",
            500: "Internal Server Error",
        },
        tags=["Conversation"],
    )
    def patch(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)


class ConversationSoftDBDeleteAPI(generics.DestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, IsAdminOfConversation]
    lookup_field = 'id'

    def get_queryset(self):
        user = self.request.user
        return Conversation.objects.filter(participants=user, is_deleted=False)

    def destroy(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.soft_delete()
        return api_response(
            is_success=True,
            result={
                "message": "Soft deleted conversation successfully."
            },
            status_code=status.HTTP_200_OK
        )

    @swagger_auto_schema(
        operation_description="Soft delete a conversation. Used only by admin of a group to delete a conversation group.",
        responses={
            200: openapi.Response(
                description="Conversation soft-deleted successfully.",
            ),
            400: "Validation Error.",
            403: "Permission Error.",
            404: "Not Found.",
            500: "Internal Server Error",
        },
        tags=["Conversation"],
    )
    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)


class ConversationSoftDeleteForUserAPI(generics.DestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, BelongsToConversation]
    lookup_field = 'id'

    def get_queryset(self):
        user = self.request.user
        return Conversation.objects.filter(participants=user, is_deleted=False)

    def perform_destroy(self, instance):
        user = self.request.user

        try:
            link = ConversationParticipant.objects.get(user=user, conversation=instance)
        except ConversationParticipant.DoesNotExist:
            raise PermissionDenied(f"{user} is not a participant.")

        if instance.is_group:
            if instance.group_admin == user:
                raise PermissionDenied("You cannot delete this chat as you're still an admin of the group. Use the 'Leave Group' function instead.")
        link.deleted_for_user = True #just letting the regular user of the group delete the convo for them if they're not admin, this line works for both 1-1 convo and regular participants of a group
        link.save()

    def destroy(self, request, *args, **kwargs):
        # try:
        super().destroy(request, *args, **kwargs)
        return api_response(
            is_success=True,
            result={
                "message": "Conversation successfully deleted for you."
            },
            status_code=status.HTTP_200_OK
        )
        # except ValidationError as ve:
        #     return api_response(
        #         is_success=False,
        #         error_message=ve.detail,
        #         status_code=status.HTTP_400_BAD_REQUEST
        #     )
        # except Exception as e:
        #     return api_response(
        #         is_success=False,
        #         error_message=str(e),
        #         status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
        #     )

    @swagger_auto_schema(
        operation_description="Soft deletes the conversation for the authenticated user. "
                                "For 1-1 chats and group participants (not admins), this marks the conversation as deleted for that user only. "
                                "Group admins must either delete the group or transfer admin before deleting for themselves.",
        responses={
            200: openapi.Response(description="Conversation successfully deleted for user."),
            400: openapi.Response(description="Validation error."),
            403: openapi.Response(description="Forbidden - you do not have permission."),
            404: openapi.Response(description="Conversation not found."),
            500: openapi.Response(description="Internal server error.")
        },
        tags=["Conversation"]
    )
    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)


class AddParticipantAPI(APIView):
    permission_classes = [IsAuthenticated, BelongsToConversation]

    def get_object(self):
        return get_object_or_404(Conversation, id=self.kwargs["id"])

    @swagger_auto_schema(
        operation_description="Add participant to a group chat. Only group chats are allowed. Requires `user_ids` as a list of integers.",
        request_body=openapi.Schema(
            type=openapi.TYPE_OBJECT,
            required=["user_ids"],
            properties={
                "user_ids": openapi.Schema(
                    type=openapi.TYPE_ARRAY,
                    items=openapi.Items(type=openapi.TYPE_INTEGER),
                    description="List of user IDs to add to the conversation."
                ),
            },
        ),
        responses={
            200: openapi.Response(
                description="Participants added successfully",
                examples={"application/json": {
                    "is_success": True,
                    "result": {"message": "Participant/s added successfully."}
                }},
            ),
            400: "Validation error",
            403: "Permission denied",
            404: "Conversation or user not found"
        },
        tags=["Conversation Utilities"]
    )
    @transaction.atomic
    def post(self, request, id):
        conversation = self.get_object()

        if not conversation.is_group: #any user of the group can add another user
            raise PermissionDenied("Participants can only be added in a group chat.")

        user_ids = request.data.get('user_ids', [])
        if not user_ids:
            raise ValidationError("No user IDs were provided.")

        #fetching all requested users
        users = User.objects.filter(id__in=user_ids)

        if users.count() != len(user_ids):
            raise ValidationError("One or more user IDs are invalid.")

        existing_users = conversation.participants.filter(id__in=user_ids)
        new_users = users.exclude(id__in=existing_users.values_list('id', flat=True))

        if not new_users:
            #if only one user is being added
            if len(user_ids) == 1:
                raise ValidationError(f"User '{existing_users.first().username}' is already a participant in this group.")
            else:
                raise ValidationError("All provided users are already participants in this group.")

        for user in new_users:
            conversation.add_participant(user)

        #if single user
        if len(user_ids) == 1:
            return api_response(
                is_success=True,
                result={"message": f"1 participant added successfully."},
                status_code=status.HTTP_200_OK
            )

        #if some participants already exist in the conversation
        if existing_users.exists():
            return api_response(
                is_success=True,
                result={"message": f"User(s) {', '.join(sorted(existing_users.values_list('username', flat=True)))} already in conversation, other participants added."},
                status_code=status.HTTP_200_OK
            )

        return api_response(
            is_success=True,
            result={"message": f"{new_users.count()} participant(s) added successfully."},
            status_code=status.HTTP_200_OK
        )


class RemoveParticipantAPI(APIView):
    permission_classes = [IsAuthenticated, IsAdminOfConversation]

    def get_object(self):
        return get_object_or_404(Conversation, id=self.kwargs["id"])

    @swagger_auto_schema(
        operation_description="Remove participants from a group chat. Only the group admin can remove participants. If removing will leave 1 or 0 participants, confirmation is required.",
        request_body=openapi.Schema(
            type=openapi.TYPE_OBJECT,
            required=["user_ids"],
            properties={
                "user_ids": openapi.Schema(
                    type=openapi.TYPE_ARRAY,
                    items=openapi.Items(type=openapi.TYPE_INTEGER),
                    description="List of user IDs to remove from the conversation."
                ),
                "confirmation": openapi.Schema(
                    type=openapi.TYPE_BOOLEAN,
                    description="Confirm if removal will delete the conversation."
                )
            },
        ),
        responses={
            200: openapi.Response(
                description="Participants removed successfully",
                examples={"application/json": {
                    "is_success": True,
                    "result": {"message": "Participants removed successfully."}
                }},
            ),
            400: "Validation error",
            403: "Permission denied",
            404: "Conversation or user not found"
        },
        tags=["Conversation Utilities"]
    )
    @transaction.atomic
    def post(self, request, id):
        conversation = self.get_object()

        if not conversation.is_group: #removing participant is only allowed in a group chat
            raise PermissionDenied("Participants can only be removed in a group chat.")

        user_ids = request.data.get('user_ids', [])
        confirmation = request.data.get('confirmation', False)

        if not user_ids:
            raise ValidationError("No user IDs were provided.")

        users_to_remove = User.objects.filter(id__in=user_ids)
        if users_to_remove.count() != len(user_ids):
            raise ValidationError("One or more user IDs are invalid.")
        for user in users_to_remove:
            conversation.remove_participants(user, request.user, confirmation)

        return api_response(
            is_success=True,
            result={"message": "Participants removed successfully."},
            status_code=status.HTTP_200_OK
        )


class LeaveGroupAPI(APIView):
    permission_classes = [IsAuthenticated, BelongsToConversation]

    def get_object(self):
        return get_object_or_404(Conversation, id=self.kwargs["id"])

    @swagger_auto_schema(
        operation_description="Leave a group conversation. If you are the admin, the next participant becomes the admin, or the conversation is deleted if only 1 participant remains.",
        request_body=openapi.Schema(
            type=openapi.TYPE_OBJECT,
            properties={
                "confirmation": openapi.Schema(
                    type=openapi.TYPE_BOOLEAN,
                    description="Confirm if leaving will delete the conversation."
                )
            },
        ),
        responses={
            200: openapi.Response(
                description="Left group successfully",
                examples={"application/json": {
                    "is_success": True,
                    "result": {"message": "You have left the group."}
                }},
            ),
            400: "Validation error",
            403: "Permission denied",
            404: "Conversation not found"
        },
        tags=["Conversation Utilities"]
    )
    @transaction.atomic
    def post(self, request, id):
        conversation = self.get_object()

        if not conversation.is_group: #leaving is allowed only in a group chat
            raise PermissionDenied("Participants can only be leave if it's a group chat.")

        confirmation = request.data.get('confirmation', False)

        conversation.leave_group(request.user, confirmation)

        return api_response(
            is_success=True,
            result={"message": "You have left the group."},
            status_code=status.HTTP_200_OK
        )
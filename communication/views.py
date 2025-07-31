from communication.models import Conversation, ConversationParticipant, Message
from communication.serializers import (
    ConversationResponseSerializer,
    ConversationCreateSerializer,
    ConversationUpdateSerializer,
    MessageResponseSerializer
)
from communication.paginations import CommunicationPagination
from communication.permissions import BelongsToConversation
from communication.filters import ConversationFilter
from myproject.utils import api_response

from rest_framework import generics, status
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import ValidationError, PermissionDenied

from django_filters.rest_framework import DjangoFilterBackend

from drf_yasg import openapi
from drf_yasg.utils import swagger_auto_schema


class ConversationListAPI(generics.ListAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, BelongsToConversation]
    serializer_class = ConversationResponseSerializer
    pagination_class = CommunicationPagination
    filter_backends = [DjangoFilterBackend]
    filterset_class = ConversationFilter

    def get_queryset(self):
        user = self.request.user
        #finding conversations not deleted by a user
        participant_qs = ConversationParticipant.objects.filter(user=user, deleted_for_user=False)
        #getting list of the convo ids
        conversation_ids = participant_qs.values_list('conversation_id', flat=True)
        #flat=True gives a plain list instead of a list of tuples.
        queryset = Conversation.objects.filter(id__in=conversation_ids)

        username = self.request.query_params.get("username")
        if username:
            queryset = queryset.filter(participants__username__icontains=username).exclude(participants=user)
        return queryset

    def list(self, request, *args, **kwargs):
        try:
            response = super().list(self, request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved conversation.",
                    "data": response.data
                },
                status_code=status.HTTP_200_OK
            )
        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
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
        try:
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
        except ValidationError as ve:
            return api_response(
                is_success=False,
                error_message=ve.detail,
                status_code=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

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
        try:
            response = super().retrieve(self, request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved conversation.",
                    "data": response.data
                },
                status_code=status.HTTP_200_OK
            )
        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
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
    permission_classes = [IsAuthenticated, BelongsToConversation]
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
        try:
            response = super().partial_update(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Updated conversation successfully.",
                    "data": response.data
                },
                status_code=status.HTTP_200_OK
            )
        except ValidationError as ve:
            return api_response(
                is_success=False,
                error_message=ve.detail,
                status_code=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        operation_description="Partially update a conversation",
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
    permission_classes = [IsAuthenticated]
    lookup_field = 'id'

    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            instance.soft_delete()
            return api_response(
                is_success=True,
                result={
                    "message": "Soft deleted conversation successfully."
                },
                status_code=status.HTTP_200_OK
            )
        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        operation_description="Soft delete a conversation",
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
        return Conversation.objects.filter(participants=user)

    def perform_destroy(self, instance):
        user = self.request.user

        if instance.is_group:
            if instance.group_admin == user:
                instance.soft_delete()
                return

        try:
            link = ConversationParticipant.objects.get(user=user, conversation=instance)
        except ConversationParticipant.DoesNotExist:
            raise PermissionError(f"{user} is not a participant.")

        if instance.is_group:
            if instance.group_admin == user:
                raise PermissionDenied("Group admins must delete the group, not leave it. They may delete the conversation for them after the admin role has been passed onto someone else.")
        link.deleted_for_user = True #just letting the regular user of the group delete the convo for them if they're not admin, this line works for both 1-1 convo and regular participants of a group
        link.save()

    def destroy(self, request, *args, **kwargs):
        try:
            super().destroy(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Conversation successfully deleted for you."
                },
                status_code=status.HTTP_200_OK
            )
        except ValidationError as ve:
            return api_response(
                is_success=False,
                error_message=ve.detail,
                status_code=status.HTTP_400_BAD_REQUEST
            )
        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
from communication.models import Conversation, Message
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
from rest_framework.exceptions import ValidationError

from django_filters.rest_framework import DjangoFilterBackend

from drf_yasg import openapi
from drf_yasg.utils import swagger_auto_schema


class ConversationListAPI(generics.ListAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, BelongsToConversation]
    serializer_class = ConversationResponseSerializer
    queryset = Conversation.objects.all()
    pagination_class = CommunicationPagination
    filter_backends = [DjangoFilterBackend]
    filterset_class = ConversationFilter

    def get_queryset(self):
        user = self.request.user
        queryset = Conversation.objects.filter(participants=user)
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
    queryset = Conversation.objects.all()
    pagination_class = CommunicationPagination

    def perform_create(self, serializer):
        serializer.save()

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            #checking if the serializer has caught an existing conversation
            if hasattr(serializer, 'existing_conversation'):
                convo_serializer = self.get_serializer(serializer.existing_conversation)
                return api_response(
                    is_success=True,
                    result={
                        "message": "Conversation already exists.",
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
    queryset = Conversation.objects.all()
    pagination_class = CommunicationPagination
    lookup_field = 'id'

    def get_queryset(self):
        return Conversation.objects.filter(participants=self.request.user)

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
    queryset = Conversation.objects.all()
    http_method_names = ["patch"]
    lookup_field = 'id'

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


class ConversationDeleteAPI(generics.DestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    queryset = Conversation.objects.all()
    lookup_field = 'id'

    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            instance.soft_delete()
            return api_response(
                is_success=True,
                result={
                    "message": "Deleted conversation successfully."
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
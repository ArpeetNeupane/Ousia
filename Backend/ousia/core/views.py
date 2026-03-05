from core.serializers import (
    EmotionCreateRetrieveUpdateSerializer,
    UserEmotionSerializer,
    HashTagRetrieveCreateUpdateSerializer,
    PostResponseCreateSerializer,
    PostUpdateSerializer,
    LikeRetrieveCreateSerializer,
    CommentRetrieveCreateSerializer,
    FriendRequestCreateSerializer,
    FriendRequestResponseSerializer,
    FriendResponseSerializer,
    FriendSerializer
)
from core.models import (
    Emotion,
    UserEmotion,
    HashTag,
    Post,
    MediaUpload,
    Like,
    Comment,
    FriendRequest,
    Friend
)
from core.paginations import DefaultPagination
from core.permissions import OwnsObjectOrAdmin, IsOwnerOfLike
from core.filters import PostFilter
from myproject.utils import api_response

from rest_framework import generics, status, filters
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound
from rest_framework.parsers import FormParser, MultiPartParser

from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi

from django.db import IntegrityError, transaction
from django.db.models import Q
from django.http import Http404
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django_filters.rest_framework import DjangoFilterBackend

import cloudinary
from datetime import timedelta



class EmotionListCreateAPI(generics.ListCreateAPIView):
    queryset = Emotion.objects.all()
    serializer_class = EmotionCreateRetrieveUpdateSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    parser_classes = [FormParser, MultiPartParser]
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']

    def get_permissions(self):
        return [IsAdminUser()] if self.request.method == 'POST' else [IsAuthenticated()]

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            try:
                with transaction.atomic():
                    serializer.save()
            except IntegrityError:
                return api_response(
                    is_success=False,
                    error_message="Emotion with this name already exists.",
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            return api_response(
                is_success=True,
                result={
                    "message": "Emotion created successfully.",
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
        operation_description="Create a new emotion. Only accessible to admins.",
        request_body=EmotionCreateRetrieveUpdateSerializer,
        responses={
            201: openapi.Response(description="Emotion created successfully."),
            400: openapi.Response(description="Validation error or duplicate emotion."),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="You do not have permission to perform this action."),
            500: openapi.Response(description="Internal server error.")
        },
        tags=["Emotion"]
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)


    def list(self, request, *args, **kwargs):
        try:
            response = super().list(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved emotions.",
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
        operation_description="Retrieve the list of all emotions.",
        responses={
            200: openapi.Response(
                description="Successfully retrieved paginated data.",
                schema=EmotionCreateRetrieveUpdateSerializer(many=True),
            ),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="You do not have permission to perform this action."),
            500: openapi.Response(description="Internal server error.")
        },
        tags=["Emotion"]
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)



class EmotionRetrieveUpdateDestroy(generics.RetrieveUpdateDestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    serializer_class = EmotionCreateRetrieveUpdateSerializer
    queryset = Emotion.objects.all()
    parser_classes = [FormParser, MultiPartParser]
    pagination_class = DefaultPagination
    http_method_names = ['get', 'patch', 'delete']

    def get_permissions(self):
        return [IsAuthenticated()] if self.request.method == 'GET' else [IsAdminUser()]

    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved emotion.",
                    "data": serializer.data
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
        operation_description="Retrieve an emotion by ID.",
        responses={
            200: openapi.Response("Successfully retrieved emotion.", EmotionCreateRetrieveUpdateSerializer),
            401: "Unauthorized - JWT token missing or invalid.",
            403: "Forbidden - Admin access required.",
            404: "Emotion not found.",
            500: "Internal server error.",
        },
        tags=["Emotion"]
    )
    def get(self, request, *args, **kwargs):
        return self.retrieve(request, *args, **kwargs)


    def partial_update(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance, data=request.data, partial=True)
            # if not serializer.is_valid():
            #     return api_response(
            #         is_success=False,
            #         error_message=serializer.errors,
            #         status_code=status.HTTP_400_BAD_REQUEST
            #     )
            serializer.is_valid(raise_exception=True)
            serializer.save()

            return api_response(
                is_success=True,
                result={
                    "message": "Emotion updated successfully.",
                    "data": serializer.data
                },
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            print(str(e))
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        operation_description="Partially update an emotion.",
        manual_parameters=[
            openapi.Parameter(
                name="id",
                in_=openapi.IN_FORM,
                type=openapi.TYPE_INTEGER,
                required=True,
                description="ID of the emotion to update"
            ),
            openapi.Parameter(
                name="emotion_emoji_name",
                in_=openapi.IN_FORM,
                type=openapi.TYPE_STRING,
                required=False,
                description="Optional emoji name"
            ),
            openapi.Parameter(
                name="emotion_image",
                in_=openapi.IN_FORM,
                type=openapi.TYPE_FILE,
                required=False,
                description="Optional image upload"
            ),
        ],
        responses={
            200: openapi.Response("Emotion updated successfully.", EmotionCreateRetrieveUpdateSerializer),
            400: "Bad request - validation failed.",
            401: "Unauthorized - JWT token missing or invalid.",
            403: "Forbidden - Admin access required.",
            404: "Emotion not found.",
            500: "Internal server error.",
        },
        tags=["Emotion"]
    )
    def patch(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)


    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            instance.delete()
            return api_response(
                is_success=True,
                result={"message": f"Emotion deleted successfully."},
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=f"Failed to delete emotion. {str(e)}",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        operation_description="Delete an emotion by ID.",
        responses={
            200: "Emotion deleted successfully.",
            401: "Unauthorized - JWT token missing or invalid.",
            403: "Forbidden - Admin access required.",
            404: "Emotion not found.",
            500: "Internal server error.",
        },
        tags=["Emotion"]
    )
    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)



class UserEmotionCreateAPIView(generics.CreateAPIView):
    queryset = UserEmotion.objects.all()
    serializer_class = UserEmotionSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        user = self.request.user

        last_emotion = UserEmotion.objects.filter(user=user).order_by('-noted_at').first()
        if last_emotion and timezone.now() - last_emotion.noted_at < timedelta(hours=1):
            raise ValidationError("You can only choose another mood after an hour. Please wait before submitting again.")
        serializer.save(user=user)

    @swagger_auto_schema(
        operation_description="Create a new user emotion entry. User can submit only one emotion per hour.",
        request_body=UserEmotionSerializer,
        responses={
            201: openapi.Response(description="User emotion created successfully.", schema=UserEmotionSerializer),
            400: openapi.Response(description="Validation error, e.g., submitting too frequently."),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="You do not have permission to perform this action."),
            500: openapi.Response(description="Internal server error."),
        },
        tags=["User Emotion"]
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)



class HashTagListCreateAPI(generics.ListCreateAPIView):
    queryset = HashTag.objects.all()
    serializer_class = HashTagRetrieveCreateUpdateSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsAuthenticated()]
        return [IsAuthenticated()]

    def perform_create(self, serializer):
        serializer.save()

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            try:
                serializer.save()
            except IntegrityError: #catching race condition; when 2 users try to create a same hashtag at the same time
                return api_response(
                    is_success=False,
                    error_message="Hashtag with this name already exists.",
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            return api_response(
                is_success=True,
                result={
                    "message": "Successfully created a hashtag.",
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
        operation_description="Create a new hashtag.",
        request_body=HashTagRetrieveCreateUpdateSerializer,
        responses={
            201: openapi.Response(description="Hashtag created successfully."),
            400: openapi.Response(description="Invalid data."),
            401: openapi.Response(description="Unauthorized."),
            403: openapi.Response(description="Permission Denied."),
            500: openapi.Response(description="Internal server error."),
        },
        tags=["HashTag"],
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)


    def list(self, request, *args, **kwargs):
        try:
            response = super().list(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved hashtags.",
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
        operation_description="Lists paginated version of hashtags.",
        responses={
            200: openapi.Response(
                description="Successfully retrieved paginated data.",
                schema=HashTagRetrieveCreateUpdateSerializer(many=True),
            ),
            204: openapi.Response(description="No content."),
            400: openapi.Response(description="Bad request."),
            401: openapi.Response(description="Unauthorized."),
            403: openapi.Response(description="Permission Denied."),
            500: openapi.Response(description="Internal Server Error."),
        },
        tags=["HashTag"],
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)



class HashTagRetrieveUpdateDestroyAPI(generics.RetrieveUpdateDestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    serializer_class = HashTagRetrieveCreateUpdateSerializer
    queryset = HashTag.objects.all()
    pagination_class = DefaultPagination
    http_method_names = ['get', 'patch', 'delete']

    def get_permissions(self):
        if self.request.method in ['PATCH', 'DELETE']:
            return [IsAuthenticated(), OwnsObjectOrAdmin()]
        return [IsAuthenticated()]

    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved hashtag.",
                    "data": serializer.data
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
        operation_description="Retrieve a singular hashtag from provided id.",
        responses={
            200: openapi.Response(
                description="Hashtag retrieved successfully",
                schema=HashTagRetrieveCreateUpdateSerializer()
            ),
            401: 'Not Authorized',
            403: 'Permission Denied',
            404: 'Hashtag not found',
            500: 'Internal Server Error.'
        },
        tags=["HashTag"]
    )
    def get(self, request, *args, **kwargs):
        return self.retrieve(request, *args, **kwargs)


    def partial_update(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance, data=request.data, partial=True)
            if not serializer.is_valid():
                return api_response(
                    is_success=False,
                    error_message=serializer.errors,
                    status_code=status.HTTP_400_BAD_REQUEST
                )
            serializer.save()

            return api_response(
                is_success=True,
                result={
                    "message": "Hashtag updated successfully.",
                    "data": serializer.data
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
        operation_description="Partially update an existing hashtag.",
        request_body=HashTagRetrieveCreateUpdateSerializer,
        responses={
            200: openapi.Response(
                description="Hashtag updated successfully",
                schema=HashTagRetrieveCreateUpdateSerializer()
            ),
            403: 'Permission denied',
            404: 'Hashtag not found',
            400: 'Validation error',
            500: 'Internal Server Error.'
        },
        tags=["HashTag"]
    )
    def patch(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)


    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            instance.delete()
            return api_response(
                is_success=True,
                result={"message": f"Hashtag deleted successfully."},
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=f"Failed to delete hashtag. {str(e)}",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        operation_description="Delete an existing hashtag.",
        responses={
            200: 'Hashtag deleted successfully',
            403: 'Permission denied',
            404: 'Hashtag not found',
            500: 'Internal Server Error.'
        },
        tags=["HashTag"]
    )
    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)



class PostListCreateAPI(generics.ListCreateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    serializer_class = PostResponseCreateSerializer
    queryset = Post.objects.all()
    parser_classes = [FormParser, MultiPartParser]
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_class = PostFilter
    ordering_fields = ['created_at', 'updated_at', 'post_like_count', 'post_comment_count']
    ordering = ['-created_at'] #default ordering

    def get_permissions(self):
        return [IsAuthenticated()]

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return api_response(
                is_success=True,
                result={
                    "message": "Post creation successful.",
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
        operation_description="Create a new post. For multiple files, use the same 'media' parameter name multiple times.",
        manual_parameters=[
            openapi.Parameter('caption', openapi.IN_FORM, type=openapi.TYPE_STRING, required=True),
            openapi.Parameter('visibility', openapi.IN_FORM, type=openapi.TYPE_STRING, 
                            enum=['public', 'private', 'friends_only'], required=False),
            openapi.Parameter('type_of_post', openapi.IN_FORM, type=openapi.TYPE_STRING, required=False),
            openapi.Parameter('media', openapi.IN_FORM, type=openapi.TYPE_FILE, required=False),
        ],
        responses={201: PostResponseCreateSerializer},
        tags=["Post"],
        consumes=["multipart/form-data"]
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)


    def list(self, request, *args, **kwargs):
        try:
            response = super().list(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved posts.",
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
        operation_description="Lists paginated version of posts.",
        responses={
            200: openapi.Response(
                description="Successfully retrieved paginated data.",
                schema=PostResponseCreateSerializer(many=True),
            ),
            204: openapi.Response(description="No content."),
            400: openapi.Response(description="Bad request."),
            401: openapi.Response(description="Unauthorized."),
            403: openapi.Response(description="Permission Denied."),
            500: openapi.Response(description="Internal Server Error."),
        },
        tags=["Post"],
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)



class PostRetrieveUpdateDeleteAPI(generics.RetrieveUpdateDestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    serializer_class = PostUpdateSerializer
    queryset = Post.objects.all()
    parser_classes = [FormParser, MultiPartParser]
    http_method_names = ['get', 'patch', 'delete']

    def get_permissions(self):
        if self.request.method in ['PATCH', 'DELETE']:
            return [IsAuthenticated(), OwnsObjectOrAdmin()]
        return [IsAuthenticated()]

    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance)
            return api_response(
                is_success=True,
                result={
                    "message": "Post successfully retrieved.",
                    "data": serializer.data
                },
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def get(self, request, *args, **kwargs):
        return self.retrieve(request, *args, **kwargs)


    def partial_update(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance, data=request.data, partial=True)
            if not serializer.is_valid():
                return api_response(
                    is_success=False,
                    error_message=serializer.errors,
                    status_code=status.HTTP_400_BAD_REQUEST
                )
            serializer.save()

            return api_response(
                is_success=True,
                result={
                    "message": "Post updated successfully.",
                    "data": serializer.data
                },
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def patch(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)


    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            instance.soft_delete()
            return api_response(
                is_success=True,
                result="Successfully deleted post.",
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=f"Failed to delete hashtag. {str(e)}",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)



class MediaDeleteAPI(generics.DestroyAPIView):
    queryset = MediaUpload.objects.all()
    permission_classes = [IsAuthenticated, OwnsObjectOrAdmin]

    def get_object(self):
        post_id = self.kwargs.get('post_id') #getting post_id from url
        media_id = self.kwargs.get('media_id') #getting media_id from url
        obj = get_object_or_404(MediaUpload, id=media_id, post_id=post_id)
        self.check_object_permissions(self.request, obj)
        return obj

    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
        except Http404: #handeling 404 from get_object_or_404
            return api_response(
                is_success=False,
                error_message="Media not found or doesn't belong to the post.",
                status_code=status.HTTP_404_NOT_FOUND
            )

        try:
            if instance.public_id:
                cloudinary.uploader.destroy(
                    instance.public_id,
                    resource_type="video" if instance.is_video else "image"
                )
            instance.delete()

            return api_response(
                is_success=True,
                result="Media successfully deleted",
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=f"Failed to delete media. {str(e)}",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        operation_description="Deletes a specific media file belonging to a post. Only the owner or an admin can perform this action.",
        responses={
            200: openapi.Response(description="Media successfully deleted"),
            400: openapi.Response(description="Bad Request"),
            401: openapi.Response(description="Unauthorized - Authentication credentials were not provided or invalid."),
            403: openapi.Response(description="Forbidden - You do not have permission to delete this media."),
            404: openapi.Response(description="Media not found or doesn't belong to the post."),
            500: openapi.Response(description="Failed to delete media due to server error."),
        },
        tags=["Post"]
    )
    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)



class LikeListCreateAPI(generics.ListCreateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = LikeRetrieveCreateSerializer
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']

    def get_queryset(self):
        queryset = Like.objects.select_related('liked_by', 'post')
        #also fetching the related User (liked_by) and Post objects in the same SQL query using a JOIN.
        post_id = self.request.query_params.get('post') #eg: url/like/?post=42
        if post_id:
            return queryset.filter(post_id=post_id)
        return queryset

    def perform_create(self, serializer):
        serializer.save(liked_by=self.request.user)

    def create(self, request, *args, **kwargs):
        try:
            response = super().create(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Like created successfully.",
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
        operation_description="Create a like on a post. If the post is already liked by the user, the existing like is returned.",
        request_body=LikeRetrieveCreateSerializer,
        responses={
            200: openapi.Response(
                description="Like created successfully.",
                schema=LikeRetrieveCreateSerializer
            ),
            400: "Validation error.",
            401: "Unauthorized",
            500: "Internal server error"
        },
        tags=["Likes"]
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)


    def list(self, request, *args, **kwargs):
        try:
            response = super().list(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Like retrieved successfully.",
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
        operation_description="Retrieve the list of likes for posts.",
        responses={
            200: openapi.Response(
                description="Likes retrieved successfully.",
                schema=LikeRetrieveCreateSerializer(many=True)
            ),
            401: "Unauthorized",
            500: "Internal server error"
        },
        tags=["Likes"]
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)



class LikeDeleteAPI(generics.DestroyAPIView):
    permission_classes = [IsAuthenticated, IsOwnerOfLike]
    authentication_classes = [JWTAuthentication]
    lookup_field = "id"

    def get_queryset(self):
        return Like.objects.filter(liked_by=self.request.user)

    @swagger_auto_schema(
        operation_description="Delete a user's like by ID.",
        responses={
            204: "No Content – successfully deleted",
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            404: "Not Found",
            500: "Internal Server Error"
        },
        tags = ["Likes"]
    )
    def delete(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.delete()
        return api_response(
            is_success=True,
            result={"message": f"Like deleted successfully."},
            status_code=status.HTTP_200_OK
        )



class CommentListCreateAPI(generics.ListCreateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = CommentRetrieveCreateSerializer
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']

    def get_queryset(self):
        queryset = Comment.objects.select_related('commented_by', 'post')
        post_id = self.request.query_params.get('post')
        if post_id:
            return queryset.filter(post_id=post_id)
        return queryset

    def perform_create(self, serializer):
        serializer.save(commented_by=self.request.user)

    def create(self, request, *args, **kwargs):
        try:
            response = super().create(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Comment created successfully.",
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
        operation_description="Create a comment on a post.",
        request_body=CommentRetrieveCreateSerializer,
        responses={
            200: openapi.Response(
                description="Like created successfully.",
                schema=CommentRetrieveCreateSerializer
            ),
            400: "Validation error.",
            401: "Unauthorized",
            500: "Internal server error"
        },
        tags=["Comments"]
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)


    def list(self, request, *args, **kwargs):
        try:
            response = super().list(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Comments retrieved successfully.",
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
        operation_description="Retrieve the list of comments for posts.",
        responses={
            200: openapi.Response(
                description="Comments retrieved successfully.",
                schema=CommentRetrieveCreateSerializer(many=True)
            ),
            401: "Unauthorized",
            500: "Internal server error"
        },
        tags=["Comments"]
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)



class FriendRequestListCreateAPI(generics.ListCreateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = FriendRequestCreateSerializer
    # queryset = FriendRequest.objects.all()
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_class = None
    ordering_fields = ['created_at', 'responded_at']
    ordering = ['-created_at']

    def get_queryset(self):
        user = self.request.user
        return FriendRequest.objects.filter(
            to_user=user, status=FriendRequest.RequestStatusEnum.PENDING
        ).select_related('from_user') #optimizing lookup in case we need info about the sender

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data, context={'request': request})
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return api_response(
                is_success=True,
                result={
                    "message": "Friend request sent successfully.",
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
        operation_description="Send a friend request to another user by specifying their user ID.",
        request_body=FriendRequestCreateSerializer,
        responses={
            201: openapi.Response(
                description="Friend request sent successfully.",
                schema=FriendRequestCreateSerializer
            ),
            400: "Validation error.",
            401: "Unauthorized",
            500: "Internal server error"
        },
        tags=["Friend Request"]
    )
    def post(self, request, *args, **kwargs):
        return self.create(request, *args, **kwargs)


    def list(self, request, *args, **kwargs):
        try:
            response = super().list(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved friend requests.",
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
        operation_description="Get a paginated list of friend requests sent to the authenticated user that are still pending.",
        responses={
            200: openapi.Response(
                description="Successfully retrieved friend requests.",
                schema=openapi.Schema(
                    type=openapi.TYPE_OBJECT,
                    properties={
                        "message": openapi.Schema(type=openapi.TYPE_STRING),
                        "data": openapi.Schema(type=openapi.TYPE_ARRAY, items=openapi.Items(type=openapi.TYPE_OBJECT)),
                    }
                )
            ),
            401: "Unauthorized",
            403: "Permission Denied",
            500: "Internal server error"
        },
        tags=["Friend Request"]
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)



class FriendRequestResponseAPI(generics.UpdateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = FriendRequestResponseSerializer
    queryset = FriendRequest.objects.all()
    http_method_names = ['patch']

    #redundant but keeping for now
    def get_object(self):
        try:
            return super().get_object()
        except Http404:
            raise NotFound("This friend request doesn't exist.")

    def partial_update(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance, data=request.data, partial=True)
            if not serializer.is_valid():
                return api_response(
                    is_success=False,
                    error_message=serializer.errors,
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            serializer.save()

            return api_response(
                is_success=True,
                result={
                    "message": f"Friend request {serializer.data['status']}.",
                    "data": serializer.data
                },
                status_code=status.HTTP_200_OK
            )

        except NotFound:
            return api_response(
                is_success=False,
                error_message="This friend request doesn't exist.",
                status_code=status.HTTP_404_NOT_FOUND
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
        operation_description="Accept or reject a friend request by updating its status.",
        request_body=FriendRequestResponseSerializer,
        responses={
            200: openapi.Response(
                description="Friend request response updated.",
                schema=FriendRequestResponseSerializer
            ),
            400: "Validation error",
            401: "Unauthorized",
            403: "Permission Denied",
            404: "Friend request not found",
            500: "Internal server error"
        },
        tags=["Friend Request"]
    )
    def patch(self, request, *args, **kwargs):
        return self.partial_update(request, *args, **kwargs)



class FriendRequestDeleteAPI(generics.DestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    queryset = FriendRequest.objects.all()
    http_method_names = ['delete']

    def perform_destroy(self, instance):
        instance.delete()

    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()

            #only allowing sender or receiver to delete it
            if request.user != instance.from_user and request.user != instance.to_user:
                raise PermissionDenied("You do not have permission to delete this friend request.")

            self.perform_destroy(instance)

            return api_response(
                is_success=True,
                result={"message": "Friend request deleted."},
                status_code=status.HTTP_200_OK
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        operation_description="Deletes a friend request. Only the sender or recipient can delete it.",
        responses={
            204: "Friend request deleted successfully.",
            401: "Unauthorized",
            403: "Permission denied",
            404: "Friend request not found",
            500: "Internal server error"
        },
        tags=["Friend Request"]
    )
    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)



class FriendListAPI(generics.ListAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = FriendSerializer
    pagination_class = DefaultPagination
    http_method_names = ['get']

    def get_queryset(self):
        user = self.request.user
        return Friend.objects.filter(
            Q(user1=user) | Q(user2=user)
        ).select_related('user1', 'user2')

    def list(self, request, *args, **kwargs):
        try:
            response = super().list(request, *args, **kwargs)
            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved friends list.",
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
        operation_description="Returns a paginated list of all friends for the authenticated user.",
        responses={
            200: openapi.Response(
                description="Successfully retrieved friends list.",
                schema=FriendResponseSerializer(many=True)
            ),
            401: "Unauthorized",
            500: "Internal server error"
        },
        tags=["Friend"]
    )
    def get(self, request, *args, **kwargs):
        return self.list(request, *args, **kwargs)
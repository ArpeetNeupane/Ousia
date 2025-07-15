from core.serializers import EmotionCreateRetrieveUpdateSerializer, HashTagRetrieveCreateUpdateSerializer, PostResponseCreateSerializer, PostUpdateSerializer, FriendRequestCreateSerializer, FriendRequestResponseSerializer, FriendResponseSerializer
from core.models import Emotion, HashTag, Post, MediaUpload, PostHashTag, Like, Comment, FriendRequest, Friend
from core.paginations import DefaultPagination
from core.permissions import OwnsObjectOrAdmin
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
from django.shortcuts import get_object_or_404
from django_filters.rest_framework import DjangoFilterBackend

import cloudinary


class EmotionListCreateAPI(generics.ListCreateAPIView):
    queryset = Emotion.objects.all()
    serializer_class = EmotionCreateRetrieveUpdateSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminUser]
    parser_classes = [FormParser, MultiPartParser]
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']

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

    def post(self, request, *args, **kwargs):
        return super().create(request, *args, **kwargs)


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

    def get(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)



class EmotionRetrieveUpdateDestroy(generics.RetrieveUpdateDestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminUser]
    serializer_class = EmotionCreateRetrieveUpdateSerializer
    queryset = Emotion.objects.all()
    parser_classes = [FormParser, MultiPartParser]
    pagination_class = DefaultPagination
    http_method_names = ['get', 'patch', 'delete']

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

    def get(self, request, *args, **kwargs):
        return super().retrieve(request, *args, **kwargs)


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

    def patch(self, request, *args, **kwargs):
        return super().partial_update(request, *args, **kwargs)


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

    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)




class HashTagListCreateAPI(generics.ListCreateAPIView):
    queryset = HashTag.objects.all()
    serializer_class = HashTagRetrieveCreateUpdateSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']

    def get_permissions(self):
        if self.request.method == 'POST':
            return [IsAdminUser()]
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
            201: openapi.Response(
                description="Successfully created a hashtag.",
                schema=HashTagRetrieveCreateUpdateSerializer,
            ),
            400: openapi.Response(description="Invalid data."),
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
            404: 'Hashtag not found',
            500: 'Internal Server Error.'
        },
        tags=["HashTag"]
    )
    def get(self, request, *args, **kwargs):
        return super().retrieve(request, *args, **kwargs)


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
        return super().partial_update(request, *args, **kwargs)


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
        operation_description="Create a new post with multiple media files.",
        manual_parameters=[
            openapi.Parameter(
                'caption',
                openapi.IN_FORM,
                description="Post caption.",
                type=openapi.TYPE_STRING,
                required=True
            ),
            openapi.Parameter(
                'visibility',
                openapi.IN_FORM,
                description="Post visibility.",
                type=openapi.TYPE_STRING,
                enum=['public', 'private', 'friends_only'],
                required=False
            ),
            openapi.Parameter(
                'type_of_post',
                openapi.IN_FORM,
                description="Hashtag names.",
                type=openapi.TYPE_STRING,
                required=False
            ),
            openapi.Parameter(
                'media',
                openapi.IN_FORM,
                description="Media files (can upload multiple).",
                type=openapi.TYPE_FILE,
                required=False
            ),
        ],
        responses={
            201: openapi.Response(
                description="Successfully created a post.",
                schema=PostResponseCreateSerializer,
            ),
            400: openapi.Response(description="Invalid data."),
            500: openapi.Response(description="Internal server error."),
        },
        tags=["Post"]
    )
    def post(self, request, *args, **kwargs):
        return super().create(request, *args, **kwargs)


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
        return super().list(request, *args, **kwargs)



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
        return super().retrieve(request, *args, **kwargs)


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
        return super().partial_update(request, *args, **kwargs)


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

    def delete(self, request, *args, **kwargs):
        return self.destroy(request, *args, **kwargs)



class FriendRequestListCreateAPI(generics.ListCreateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = FriendRequestCreateSerializer
    queryset = FriendRequest.objects.all()
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

    def post(self, request, *args, **kwargs):
        return super().create(request, *args, **kwargs)


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

    def get(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)



class FriendRequestResponseAPI(generics.UpdateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = FriendRequestResponseSerializer
    queryset = FriendRequest.objects.all()
    http_method_names = ['patch']

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
                status_code=status.HTTP_403_FORBIDDEN
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

    def patch(self, request, *args, **kwargs):
        return super().partial_update(request, *args, **kwargs)



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
                status_code=status.HTTP_204_NO_CONTENT
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def delete(self, request, *args, **kwargs):
        return super().destroy(request, *args, **kwargs)



class FriendResponseAPI(generics.ListAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = FriendResponseSerializer
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

    def get(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)
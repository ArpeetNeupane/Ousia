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
    FriendSerializer,
    UserSessionStartSerializer,
    ModerationQueuePostSerializer,
    ModerationActionSerializer,
    NotificationSerializer,
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
    Friend,
    UserSession,
    Notification,
)
from core.paginations import DefaultPagination, HashTagPagination, NotificationPagination
from core.permissions import OwnsObjectOrAdmin, IsOwnerOfLike
from core.filters import PostFilter
from core.utils.nsfw_classifier import moderate_post, NSFWVerdict
from core.notifications import create_notification
from accounts.models import User
from accounts.interest_sync import get_user_interest_hashtag_ids
from myproject.utils import api_response

from rest_framework import generics, status, filters
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from rest_framework.exceptions import ValidationError, PermissionDenied, NotFound
from rest_framework.parsers import FormParser, MultiPartParser

from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi

from django.db import IntegrityError, transaction
from django.db.models import Q, Count
from django.http import Http404
from django.utils import timezone
from django.shortcuts import get_object_or_404
from django_filters.rest_framework import DjangoFilterBackend

import cloudinary, os, tempfile, random, datetime
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
    pagination_class = HashTagPagination
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
    #reverse relationship name of fk of post on like model is like_on_post
    # queryset = Post.objects.prefetch_related("like_on_post").filter(
    #     moderation_status = "approved"
    # )
    parser_classes = [FormParser, MultiPartParser]
    pagination_class = DefaultPagination
    http_method_names = ['get', 'post']
    filter_backends = [DjangoFilterBackend, filters.OrderingFilter]
    filterset_class = PostFilter
    ordering_fields = ['created_at', 'updated_at', 'post_like_count', 'post_comment_count']
    ordering = ['-created_at'] #default ordering

    def get_permissions(self):
        return [IsAuthenticated()]

    def get_queryset(self):
        user = self.request.user
        posted_by_username = self.request.query_params.get('posted_by')
        
        #when viewing a specific user's posts, skip visibility filter
        if posted_by_username:
            return Post.objects.prefetch_related("like_on_post", "type_of_post").annotate(
                like_count=Count('like_on_post')
            ).filter(
                status=Post.ModerationStatus.APPROVED,
                posted_by__username=posted_by_username
            ).distinct().order_by('-created_at') #default ordering newest first for profile grid
        
        #feed with visibility filtering + scoring
        friends = Friend.objects.filter(
            Q(user1=user) | Q(user2=user),
            is_blocked=False
        ).values_list('user1', 'user2')
        
        friend_ids = set()
        for user1_id, user2_id in friends:
            if user1_id == user.id:
                friend_ids.add(user2_id)
            else:
                friend_ids.add(user1_id)

        interest_hashtag_ids = get_user_interest_hashtag_ids(user)

        base_queryset = Post.objects.prefetch_related("like_on_post", "type_of_post").annotate(
            like_count=Count('like_on_post')
        ).filter(
            status=Post.ModerationStatus.APPROVED
        ).filter(
            Q(visibility=Post.VisibilityEnum.PUBLIC) |
            Q(visibility=Post.VisibilityEnum.FRIENDS_ONLY, posted_by__in=friend_ids) |
            Q(posted_by=user)
        ).distinct()

        if interest_hashtag_ids:
            interest_filtered = base_queryset.filter(
                Q(type_of_post__id__in=interest_hashtag_ids) | Q(posted_by=user)
            ).distinct()
            if interest_filtered.exists():
                return interest_filtered

        return base_queryset

    def create(self, request, *args, **kwargs):
        try:
            serializer = self.get_serializer(data=request.data)
            serializer.is_valid(raise_exception=True)

            caption = request.data.get('caption', '') or ''
            media_uploads = request.FILES.getlist('media')

            for upload in media_uploads:
                upload.seek(0)

            # Save uploaded files to temp paths for moderation
            temp_files = []
            media_for_moderation = []
            try:
                for upload in media_uploads:
                    suffix = os.path.splitext(upload.name)[1]
                    tmp = tempfile.NamedTemporaryFile(delete=False, suffix=suffix)
                    for chunk in upload.chunks():
                        tmp.write(chunk)
                    tmp.close()
                    is_video = upload.content_type.startswith('video/') or suffix.lower() in ['.mp4', '.mkv']
                    temp_files.append(tmp.name)
                    media_for_moderation.append({'path': tmp.name, 'is_video': is_video})

                print(f"CAPTION: {caption}")
                print(f"MEDIA FILES: {[(m['path'], os.path.getsize(m['path'])) for m in media_for_moderation]}")
                mod_result = moderate_post(caption=caption, media_files=media_for_moderation)
                print(f"MOD RESULT: {mod_result}")

                for upload in media_uploads:
                    upload.seek(0)

            finally:
                for path in temp_files:
                    try:
                        os.unlink(path)
                    except Exception:
                        pass

            if mod_result.verdict == NSFWVerdict.BLOCK:
                return api_response(
                    is_success=False,
                    error_message={
                        "caption": f"Post blocked due to content violating community guidelines: {mod_result.reason} (model: {mod_result.model_used}, score: {mod_result.score:.3f}, label: {mod_result.label})"
                    },
                    status_code=status.HTTP_400_BAD_REQUEST
                )
        
            post = serializer.save()

            post.moderation_status = 'pending_review' if mod_result.verdict == NSFWVerdict.REVIEW else 'approved'
            post.status = post.moderation_status
            post.ai_score = mod_result.score
            post.moderation_score = mod_result.score
            post.moderation_label = mod_result.label
            post.moderation_model = mod_result.model_used
            post.moderation_reason = mod_result.reason
            post.save(update_fields=[
                'status', 'ai_score',
                'moderation_status', 'moderation_score',
                'moderation_label', 'moderation_model', 'moderation_reason'
            ])

            success_message = (
                "Post submitted for review."
                if post.status == Post.ModerationStatus.PENDING_REVIEW
                else "Post creation successful."
            )

            return api_response(
                is_success=True,
                result={
                    "message": success_message,
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
            queryset = self.get_queryset()
            posted_by = request.query_params.get('posted_by')

            if posted_by:
                #no scoring for profile grid
                page = self.paginate_queryset(queryset)
                if page is not None:
                    serializer = self.get_serializer(page, many=True)
                    paginated = self.get_paginated_response(serializer.data)
                    return api_response(
                        is_success=True,
                        result={"message": "Successfully retrieved posts.", "data": paginated.data},
                        status_code=status.HTTP_200_OK
                    )
                serializer = self.get_serializer(queryset, many=True)
                return api_response(
                    is_success=True,
                    result={"message": "Successfully retrieved posts.", "data": serializer.data},
                    status_code=status.HTTP_200_OK
                )

            #feed scoring
            now = timezone.now()
            import datetime
            daily_seed = int(datetime.date.today().strftime('%Y%m%d')) + request.user.id
            rng = random.Random(daily_seed)

            posts = list(queryset)
            interest_hashtag_ids = set(get_user_interest_hashtag_ids(request.user))
            scored = []
            for post in posts:
                hours_old = max((now - post.created_at).total_seconds() / 3600, 1)
                recency_score = 1 / (hours_old ** 0.5)
                like_score = post.like_count * 0.5
                interest_match_count = 0
                if interest_hashtag_ids:
                    post_hashtag_ids = {tag.id for tag in post.type_of_post.all()}
                    interest_match_count = len(post_hashtag_ids.intersection(interest_hashtag_ids))
                random_score = rng.uniform(0, 0.3)
                total = recency_score + like_score + random_score + (interest_match_count * 2)
                scored.append((total, post))

            scored.sort(key=lambda x: x[0], reverse=True)
            sorted_posts = [p for _, p in scored]

            page = self.paginate_queryset(sorted_posts)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                paginated = self.get_paginated_response(serializer.data)
                return api_response(
                    is_success=True,
                    result={"message": "Successfully retrieved posts.", "data": paginated.data},
                    status_code=status.HTTP_200_OK
                )

            serializer = self.get_serializer(sorted_posts, many=True)
            return api_response(
                is_success=True,
                result={"message": "Successfully retrieved posts.", "data": serializer.data},
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
                error_message=f"Failed to delete post. {str(e)}",
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
            post_id = request.data.get('post')
            already_liked = False
            if post_id:
                already_liked = Like.objects.filter(
                    liked_by=request.user,
                    post_id=post_id,
                ).exists()

            response = super().create(request, *args, **kwargs)

            if post_id and not already_liked:
                like = Like.objects.select_related('post', 'post__posted_by').filter(
                    liked_by=request.user,
                    post_id=post_id,
                ).first()
                if like and like.post and like.post.posted_by_id != request.user.id:
                    create_notification(
                        recipient=like.post.posted_by,
                        actor=request.user,
                        notification_type=Notification.NotificationTypes.LIKE,
                        title='New like',
                        body=f"{request.user.username} liked your post.",
                        data={
                            'post_id': like.post_id,
                            'like_id': like.id,
                        },
                    )

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
            Q(to_user=user) | Q(from_user=user)
        ).select_related('from_user', 'to_user') #optimizing lookup in case we need info about the sender

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        friend_request = serializer.save()

        create_notification(
            recipient=friend_request.to_user,
            actor=request.user,
            notification_type=Notification.NotificationTypes.FRIEND_REQUEST,
            title='New friend request',
            body=f"{request.user.username} sent you a friend request.",
            data={
                'friend_request_id': friend_request.id,
                'from_user_id': request.user.id,
            },
        )

        return api_response(
            is_success=True,
            result={
                "message": "Friend request sent successfully.",
                "data": serializer.data
            },
            status_code=status.HTTP_201_CREATED
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


class AdminDashboardSummaryAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminUser]

    def get(self, request, *args, **kwargs):
        now = timezone.now()
        month_ago = now - timedelta(days=30)

        total_users = User.objects.filter(is_deleted=False).count()
        new_users_past_month = User.objects.filter(is_deleted=False, date_joined__gte=month_ago).count()

        total_posts = Post.objects.filter(is_deleted=False).count()
        new_posts_past_month = Post.objects.filter(is_deleted=False, created_at__gte=month_ago).count()

        moderation_queue_count = Post.objects.filter(
            is_deleted=False,
            status=Post.ModerationStatus.PENDING_REVIEW,
        ).count()

        active_poster_ids = Post.objects.filter(is_deleted=False).values_list('posted_by_id', flat=True).distinct()
        active_posters = len(active_poster_ids)
        silent_users = max(total_users - active_posters, 0)

        active_session_users = UserSession.objects.filter(start_time__gte=month_ago).values('user_id').distinct().count()
        retention_rate = round((active_session_users / total_users) * 100, 1) if total_users else 0.0

        return api_response(
            is_success=True,
            result={
                'total_users': total_users,
                'new_users_past_month': new_users_past_month,
                'total_posts': total_posts,
                'new_posts_past_month': new_posts_past_month,
                'moderation_queue_count': moderation_queue_count,
                'engagement_ratio': {
                    'active_posters': active_posters,
                    'silent_users': silent_users,
                },
                'retention_rate': retention_rate,
            },
            status_code=status.HTTP_200_OK,
        )


class AdminDashboardScreenTimeAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminUser]

    def get(self, request, *args, **kwargs):
        try:
            days = int(request.query_params.get('days', 7))
        except ValueError:
            days = 7

        days = max(1, min(days, 90))
        now = timezone.now()
        since = now - timedelta(days=days)

        sessions = UserSession.objects.select_related('user').filter(
            Q(start_time__gte=since) |
            Q(end_time__gte=since) |
            Q(end_time__isnull=True)
        )

        per_user_seconds = {}
        for session in sessions:
            start = max(session.start_time, since)
            session_end = session.end_time or now
            end = min(session_end, now)
            if end <= start:
                continue
            seconds = int((end - start).total_seconds())
            if seconds <= 0:
                continue
            username = session.user.username
            per_user_seconds[username] = per_user_seconds.get(username, 0) + seconds

        payload = [
            {
                'username': username,
                'total_minutes': int(total_seconds / 60),
            }
            for username, total_seconds in sorted(per_user_seconds.items(), key=lambda x: x[1], reverse=True)
        ]

        return api_response(
            is_success=True,
            result=payload,
            status_code=status.HTTP_200_OK,
        )


class AdminModerationQueueAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminUser]

    def get(self, request, *args, **kwargs):
        queryset = Post.objects.filter(
            is_deleted=False,
            status=Post.ModerationStatus.PENDING_REVIEW,
        ).select_related('posted_by').prefetch_related('post_media').order_by('-created_at')

        serializer = ModerationQueuePostSerializer(queryset, many=True)
        return api_response(
            is_success=True,
            result={'data': serializer.data},
            status_code=status.HTTP_200_OK,
        )


class AdminModerationActionAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminUser]
    serializer_class = ModerationActionSerializer

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        post_id = serializer.validated_data['post_id']
        action = serializer.validated_data['action']

        post = get_object_or_404(Post, id=post_id, is_deleted=False)
        new_status = Post.ModerationStatus.APPROVED if action == 'approve' else Post.ModerationStatus.BLOCKED

        post.status = new_status
        post.moderation_status = new_status
        post.save(update_fields=['status', 'moderation_status'])

        is_approved = action == 'approve'
        create_notification(
            recipient=post.posted_by,
            actor=request.user,
            notification_type=Notification.NotificationTypes.POST_MODERATION,
            title='Post approved' if is_approved else 'Post rejected',
            body=(
                'Your post has been approved and is now visible.'
                if is_approved
                else 'Your post was rejected by moderation review.'
            ),
            data={
                'post_id': post.id,
                'status': post.status,
                'action': action,
            },
        )

        return api_response(
            is_success=True,
            result={
                'message': f'Post {action}d successfully.',
                'data': {
                    'post_id': post.id,
                    'status': post.status,
                }
            },
            status_code=status.HTTP_200_OK,
        )


class SessionStartAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = UserSessionStartSerializer

    def post(self, request, *args, **kwargs):
        session = UserSession.objects.create(user=request.user)
        data = self.get_serializer(session).data
        return api_response(
            is_success=True,
            result={
                'session_id': data['id'],
                'data': data,
            },
            status_code=status.HTTP_201_CREATED,
        )


class SessionUpdateAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = UserSessionStartSerializer

    def patch(self, request, *args, **kwargs):
        session = get_object_or_404(UserSession, id=self.kwargs['session_id'], user=request.user)
        session.end_time = timezone.now()
        session.save(update_fields=['end_time', 'duration_seconds'])

        data = self.get_serializer(session).data
        return api_response(
            is_success=True,
            result={
                'session_id': data['id'],
                'data': data,
            },
            status_code=status.HTTP_200_OK,
        )


class SessionEndAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = UserSessionStartSerializer

    def post(self, request, *args, **kwargs):
        session = get_object_or_404(UserSession, id=self.kwargs['session_id'], user=request.user)
        session.end_time = timezone.now()
        session.save(update_fields=['end_time', 'duration_seconds'])

        data = self.get_serializer(session).data
        return api_response(
            is_success=True,
            result={
                'session_id': data['id'],
                'data': data,
            },
            status_code=status.HTTP_200_OK,
        )


class NotificationListAPI(generics.ListAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer
    pagination_class = NotificationPagination

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user).select_related('actor')

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        return api_response(
            is_success=True,
            result={
                'message': 'Notifications retrieved successfully.',
                'data': response.data,
            },
            status_code=status.HTTP_200_OK,
        )


class NotificationMarkReadAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer

    def patch(self, request, *args, **kwargs):
        notification = get_object_or_404(
            Notification,
            id=self.kwargs['notification_id'],
            recipient=request.user,
        )
        if not notification.is_read:
            notification.is_read = True
            notification.save(update_fields=['is_read'])

        return api_response(
            is_success=True,
            result={
                'message': 'Notification marked as read.',
                'data': self.get_serializer(notification).data,
            },
            status_code=status.HTTP_200_OK,
        )


class NotificationMarkAllReadAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer

    def post(self, request, *args, **kwargs):
        updated_count = Notification.objects.filter(
            recipient=request.user,
            is_read=False,
        ).update(is_read=True)

        return api_response(
            is_success=True,
            result={
                'message': 'All notifications marked as read.',
                'updated_count': updated_count,
            },
            status_code=status.HTTP_200_OK,
        )


class NotificationUnreadCountAPI(generics.GenericAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = NotificationSerializer

    def get(self, request, *args, **kwargs):
        unread_count = Notification.objects.filter(
            recipient=request.user,
            is_read=False,
        ).count()

        return api_response(
            is_success=True,
            result={
                'unread_count': unread_count,
            },
            status_code=status.HTTP_200_OK,
        )
from rest_framework.views import APIView
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.throttling import ScopedRateThrottle
from rest_framework import generics
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.permissions import IsAuthenticated, IsAdminUser

from django.shortcuts import get_object_or_404

from accounts.models import User, Profile, AreaOfInterest, UserAreaOfInterest
from accounts.serializers import UserRegistrationSerializer, UserLoginSerializer, UserPasswordUpdateSerializer, ProfileUpdateSerializer, ProfileAdminUpdateSerializer, ProfileSerializer, AreaOfInterestSerializer, UserAreaOfInterestSerializer, UserSearchSerializer
from accounts.permissions import IsAuthenticatedOrAdmin, IsOwnerOfProfile, CreatorOfInterest, IsOwnerOfUserInterest
from accounts.paginations import DefaultPagination
from myproject.utils import api_response, blacklist_user_tokens

from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi


class RegisterView(APIView):
    permission_classes = [AllowAny]
    parser_classes = [FormParser, MultiPartParser]

    @swagger_auto_schema(   
        operation_description="Register a new user.",
        request_body=UserRegistrationSerializer,
        responses={
            201: openapi.Response(
                description="User registered successfully.",
            ),
            400: openapi.Response(
                description="Invalid data.",
            ),
            500: openapi.Response(
                description="Internal server error.",
            ),
        },
        tags=["User"],
    )
    def post(self, request, *args, **kwargs):
        serializer = UserRegistrationSerializer(data=request.data)

        try:
            if serializer.is_valid():
                serializer.save()
                return api_response(
                    is_success=True,
                    result={"message": "User registered successfully. Please redirect to the login screen to continue."},
                    status_code=status.HTTP_201_CREATED,
                )
            return api_response(
                is_success=False,
                error_message=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )
        except Exception as e:
            print(str(e))
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            ) 


class LoginView(APIView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'login'
    permission_classes = [AllowAny]

    @swagger_auto_schema(
        operation_description="Login a user.",
        request_body=openapi.Schema(
            type=openapi.TYPE_OBJECT,
            properties={
                "username": openapi.Schema(
                    type=openapi.TYPE_STRING, description="The username of the user."
                ),
                "password": openapi.Schema(
                    type=openapi.TYPE_STRING, description="The password of the user."
                ),
            },
            required=["username", "password"],
        ),
        responses={
            200: openapi.Response(
                description="User logged in successfully.",
                schema=openapi.Schema(
                    type=openapi.TYPE_OBJECT,
                ),
            ),
            400: openapi.Response(
                description="Invalid data",
            ),
            401: openapi.Response(
                description="Invalid credentials",
            ),
            500: openapi.Response(
                description="Internal server error",
            ),
        },
        tags=["User"],
    )
    def post(self, request, *args, **kwargs):
        serializer = UserLoginSerializer(data=request.data)
        try:
            if serializer.is_valid():
                return api_response(
                    is_success=True,
                    result={
                        "message": "Logged in successfully.",
                        "data": serializer.data
                    },
                    status_code=status.HTTP_200_OK,
                )
            return api_response(
                is_success=False,
                error_message=serializer.errors,
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class UserPasswordUpdateAPI(APIView):
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'update_password'
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    @swagger_auto_schema(
        operation_description="Update the authenticated user's password. Requires old and new password.",
        request_body=UserPasswordUpdateSerializer,
        responses={
            200: openapi.Response(
                description="Password updated successfully.",
                examples={
                    "application/json": {
                        "is_success": True,
                        "result": {"message": "Password updated successfully."}
                    }
                }
            ),
            400: openapi.Response(description="Bad request – validation failed."),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="User is not authorized to perform this action."),
            500: openapi.Response(description="Server error.")
        },
        tags = ["User"],
    )
    def put(self, request, *args, **kwargs):
        try:
            serializer = UserPasswordUpdateSerializer(instance=request.user, data=request.data, partial=True) #partial true as username is read_only
            if not serializer.is_valid():
                return api_response(
                    is_success=False,
                    error_message=serializer.errors,
                    status_code=status.HTTP_400_BAD_REQUEST
                )

            serializer.save()
            blacklist_user_tokens(request.user)
            return api_response(
                    is_success=True,
                    result={
                        "message": "Password updated successfully.",
                    },
                    status_code=status.HTTP_200_OK
                )

        except Exception as e:
            return api_response(
                    is_success=False,
                    error_message=str(e),
                    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
                )


class ProfileResponseAPI(generics.RetrieveAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    serializer_class = ProfileSerializer

    def get_object(self):
        return get_object_or_404(Profile, user=self.request.user)

    def retrieve(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance)
            return api_response(
                is_success=True,
                result={
                    "message": "Profile data retrieved successfully.",
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
        operation_description="Retrieve profile data of currently logged in user.",
        responses={
            200: openapi.Response("Successfully retrieved profile data.", ProfileSerializer),
            401: "Unauthorized - JWT token missing or invalid.",
            403: "Forbidden",
            404: "Emotion not found.",
            500: "Internal server error.",
        },
        tags=["User"]
    )
    def get(self, request, *args, **kwargs):
        return self.retrieve(request, *args, **kwargs)


class ProfileUpdateAPI(generics.UpdateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsOwnerOfProfile]
    serializer_class = ProfileUpdateSerializer
    parser_classes = [FormParser, MultiPartParser]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'update_username'
    http_method_names = ["patch"]

    def get_object(self):
        user_id_param = self.kwargs.get("user_id")

        if user_id_param is not None:
            try:
                user_id = int(user_id_param)
            except (ValueError, TypeError):
                raise NotFound("Invalid user ID in URL.")

            #superuser or admin OR current user can access it
            if not (self.request.user.is_superuser or getattr(self.request.user, "is_admin", False) or self.request.user.id == user_id):
                raise PermissionDenied("You are not authorized to update this profile.")
        else:
            # no user_id passed, fallback to current user's own profile
            user_id = self.request.user.id

        try:
            return Profile.objects.get(user__id=user_id)
        except Profile.DoesNotExist:
            raise NotFound("Profile not found for the user.")

    @swagger_auto_schema(
        operation_description="Update a user's profile by user_id.",
        request_body=ProfileUpdateSerializer,
        responses={
            200: openapi.Response(
                description="Profile updated successfully.",
                examples={
                    "application/json": {
                        "is_success": True,
                        "result": {
                            "message": "Profile updated successfully.",
                            "data": {
                                "first_name": "John",
                                "last_name": "Doe"
                            }
                        }
                    }
                }
            ),
            400: openapi.Response(description="Invalid data provided."),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="You are not authorized to update this profile."),
            404: openapi.Response(description="Profile not found."),
            500: openapi.Response(description="Internal server error.")
        },
        tags = ["User"],
    )
    def patch(self, request, *args, **kwargs):
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
                    "message": "Profile updated successfully.",
                    "data": serializer.data
                },
                status_code=status.HTTP_200_OK
            )

        except Profile.DoesNotExist:
            return api_response(
                is_success=False,
                error_message="Profile not found for the user.",
                status_code=status.HTTP_404_NOT_FOUND
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ProfileAdminUpdateAPI(generics.UpdateAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAdminUser]
    serializer_class = ProfileAdminUpdateSerializer
    parser_classes = [FormParser, MultiPartParser]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = 'update_username'
    http_method_names = ["patch"]
    lookup_field = 'user_id'

    def get_object(self):
        user_id_param = self.kwargs.get("user_id")
        if user_id_param is not None:
            try:
                user_id = int(user_id_param)
            except (ValueError, TypeError):
                raise NotFound("Invalid user ID in URL.")
            if not (self.request.user.is_superuser or getattr(self.request.user, "is_admin", False) or self.request.user.id == user_id):
                raise PermissionDenied("You are not authorized to update this profile.")
            try:
                return Profile.objects.get(user__id=user_id)
            except Profile.DoesNotExist:
                raise NotFound("Profile not found for the specified user.")
        else:
            raise PermissionDenied("You are not authorized to access this endpoint.")

    @swagger_auto_schema(
        operation_description="Update a user's profile by user_id. Only accessible to superusers and admin.",
        request_body=ProfileUpdateSerializer,
        manual_parameters=[
            openapi.Parameter(
                name="user_id",
                in_=openapi.IN_PATH,
                type=openapi.TYPE_INTEGER,
                required=True,
                description="Only for superusers/admins. ID of the user to update."
            )
        ],
        responses={
            200: openapi.Response(
                description="Profile updated successfully.",
                examples={
                    "application/json": {
                        "is_success": True,
                        "result": {
                            "message": "Profile updated successfully.",
                            "data": {
                                "first_name": "John",
                                "last_name": "Doe"
                            }
                        }
                    }
                }
            ),
            400: openapi.Response(description="Invalid data provided."),
            401: openapi.Response(description="Authentication credentials were not provided or are invalid."),
            403: openapi.Response(description="You are not authorized to update this profile."),
            404: openapi.Response(description="Profile not found."),
            500: openapi.Response(description="Internal server error.")
        },
        tags = ["User"],
    )
    def patch(self, request, *args, **kwargs):
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
                    "message": "Profile updated successfully.",
                    "data": serializer.data
                },
                status_code=status.HTTP_200_OK
            )

        except Profile.DoesNotExist:
            return api_response(
                is_success=False,
                error_message="Profile not found for the user.",
                status_code=status.HTTP_404_NOT_FOUND
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )



class UserProfileDetailAPI(APIView):
    permission_classes = [IsAuthenticated]
    authentication_classes = [JWTAuthentication]

    @swagger_auto_schema(
        operation_summary="Retrieve other users profile",
        operation_description="Returns the profile details for the given user id.",
        responses={
            200: openapi.Response(
                description="Profile retrieved successfully",
                schema=ProfileSerializer()
            ),
            401: "Unauthorized",
            403: "Forbidden",
            404: "Profile not found",
            500: "Internal server error",
        },
        tags=["User"]
    )
    def get(self, request, user_id):
        try:
            profile = Profile.objects.select_related('user').get(user__id=user_id)
        except Profile.DoesNotExist:
            return api_response(
                is_success=False,
                error_message="Profile doesn't exist because user doesn't exist for that id.",
                status_code=status.HTTP_404_NOT_FOUND
            )

        serializer = ProfileSerializer(profile)
        return api_response(
            is_success=True,
            result={
                "message": " Profile retrieved successfully.",
                "data": serializer.data
            },
            status_code=status.HTTP_200_OK
        )



class AreaOfInterestListCreateAPI(generics.ListCreateAPIView):
    serializer_class = AreaOfInterestSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    queryset = AreaOfInterest.objects.all()
    pagination_class = None
    http_method_names = ["get", "post"]
    
    @swagger_auto_schema(
        operation_description="List an area of interest.",
        responses={
            200: AreaOfInterestSerializer(many=True),
            201: AreaOfInterestSerializer,
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            500: "Internal Server Error"
        },
        tags = ["Interests"]
    )
    def get(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        return api_response(
            is_success=True,
            result={
                "message": "Successfully retrieved area of interests.",
                "data": response.data
            },
            status_code=status.HTTP_200_OK
        )
    
    def perform_create(self, serializer):
        serializer.save(created_by=self.request.user)

    @swagger_auto_schema(
        operation_description="Create an area of interest.",
        request_body=AreaOfInterestSerializer,
        responses={
            201: AreaOfInterestSerializer,
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            500: "Internal Server Error"
        },
        tags = ["Interests"]
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer) #only mixin calls perform create automatically (or super().create())
        serializer.save()

        return api_response(
            is_success=True,
            result={
                "message": "Area of Interest created successfully.",
                "data": serializer.data
            },
            status_code=status.HTTP_201_CREATED
        )


class AreaOfInterestRetrieveAPI(generics.RetrieveAPIView):
    serializer_class = AreaOfInterestSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    queryset = AreaOfInterest.objects.all()
    lookup_field = "id"

    @swagger_auto_schema(
        operation_description="Retrieve a single area of interest by its ID.",
        responses={
            200: AreaOfInterestSerializer,
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            404: "Not Found",
            500: "Internal Server Error"
        },
        tags = ["Interests"]
    )
    def get(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        return api_response(
            is_success=True,
            result={
                "message": "Successfully retrieved area of interest.",
                "data": serializer.data
            },
            status_code=status.HTTP_200_OK
        )   


class AreaOfInterestUpdateAPI(generics.UpdateAPIView):
    serializer_class = AreaOfInterestSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, CreatorOfInterest]
    queryset = AreaOfInterest.objects.all()
    lookup_field = "id"
    http_method_names = ["patch"]

    @swagger_auto_schema(
        operation_description="Update an area of interest.",
        request_body=AreaOfInterestSerializer,
        responses={
            200: AreaOfInterestSerializer,
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            404: "Not Found",
            500: "Internal Server Error"
        },
        tags = ["Interests"]
    )
    def patch(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()

        return api_response(
            is_success=True,
            result={
                "message": "Area of Interest updated successfully.",
                "data": serializer.data
            },
            status_code=status.HTTP_200_OK
        )


class AreaOfInterestDeleteAPI(generics.DestroyAPIView):
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, CreatorOfInterest]
    queryset = AreaOfInterest.objects.all()
    lookup_field = "id"

    @swagger_auto_schema(
        operation_description="Delete an area of interest by its ID. Only the creator can delete.",
        responses={
            204: "No Content – successfully deleted",
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            404: "Not Found",
            500: "Internal Server Error"
        },
        tags = ["Interests"]
    )
    def delete(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.delete()
        return api_response(
            is_success=True,
            result={"message": f"Area of Interest deleted successfully."},
            status_code=status.HTTP_200_OK
        )


class UserAreaOfInterestListCreateAPI(generics.ListCreateAPIView):
    serializer_class = UserAreaOfInterestSerializer
    authentication_classes = [JWTAuthentication]
    pagination_class = DefaultPagination
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return UserAreaOfInterest.objects.filter(user=self.request.user)

    @swagger_auto_schema(
        operation_description="List all your selected areas of interest.",
        responses={
            200: UserAreaOfInterestSerializer(many=True),
            201: UserAreaOfInterestSerializer,
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            500: "Internal Server Error"
        },
        tags = ["User Interests"]
    )
    def get(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        return api_response(
            is_success=True,
            result={
                "message": "Successfully retrieved user's area of interests.",
                "data": response.data
            },
            status_code=status.HTTP_200_OK
        )

    @swagger_auto_schema(
        operation_description="Add a new area of interest for the user.",
        request_body=UserAreaOfInterestSerializer,
        responses={
            201: UserAreaOfInterestSerializer,
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            500: "Internal Server Error"
        },
        tags = ["User Interests"]
    )
    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        serializer.save(user=request.user)

        #setting has_completed_interests = True for this user so that we know where to navigate this user on future logins
        user = request.user
        user.has_completed_interests = True
        user.save(update_fields=['has_completed_interests'])

        return api_response(
            is_success=True,
            result={
                "message": "User's Area of Interest created successfully.",
                "data": serializer.data
            },
            status_code=status.HTTP_201_CREATED
        )


class UserAreaOfInterestRetrieveAPI(generics.RetrieveAPIView):
    serializer_class = UserAreaOfInterestSerializer
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated, IsOwnerOfUserInterest]
    lookup_field = "id"

    def get_queryset(self):
        return UserAreaOfInterest.objects.filter(user=self.request.user)

    @swagger_auto_schema(
        operation_description="Retrieve a single user-selected area of interest by ID.",
        responses={
            200: UserAreaOfInterestSerializer,
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            404: "Not Found",
            500: "Internal Server Error"
        },
        tags = ["User Interests"]
    )
    def get(self, request, *args, **kwargs):
        instance = self.get_object()
        serializer = self.get_serializer(instance)
        return api_response(
            is_success=True,
            result={
                "message": "Successfully retrieved user's area of interest.",
                "data": serializer.data
            },
            status_code=status.HTTP_200_OK
        )   


class UserAreaOfInterestDeleteAPI(generics.DestroyAPIView):
    permission_classes = [IsAuthenticated, IsOwnerOfUserInterest]
    authentication_classes = [JWTAuthentication]
    lookup_field = "id"

    def get_queryset(self):
        return UserAreaOfInterest.objects.filter(user=self.request.user)

    @swagger_auto_schema(
        operation_description="Delete a user-selected area of interest by ID.",
        responses={
            204: "No Content – successfully deleted",
            400: "Bad Request",
            401: "Unauthorized",
            403: "Permission Denied",
            404: "Not Found",
            500: "Internal Server Error"
        },
        tags = ["User Interests"]
    )
    def delete(self, request, *args, **kwargs):
        instance = self.get_object()
        instance.delete()
        return api_response(
            is_success=True,
            result={"message": f"User's Area of Interest deleted successfully."},
            status_code=status.HTTP_200_OK
        )


class DeleteAccountAPI(APIView):
    permission_classes = [IsAuthenticated]

    def delete(self, request):
        user = request.user
        user.soft_delete()
        return api_response(
            is_success=True,
            result={"message": "Account deleted successfully."},
            status_code=status.HTTP_200_OK
        )


class UserSearchAPI(generics.ListAPIView):
    permission_classes = [IsAuthenticated]
    serializer_class = UserSearchSerializer

    def get_queryset(self):
        query = self.request.query_params.get('q', '').strip()
        if not query:
            return User.objects.none()
        return User.objects.filter(
            username__icontains=query,
            is_deleted=False,
            is_active=True,
        ).exclude(id=self.request.user.id)[:20]

    def list(self, request, *args, **kwargs):
        queryset = self.get_queryset()
        serializer = self.get_serializer(queryset, many=True)
        return api_response(
            is_success=True,
            result={
                'message': "User search results retrieved successfully.",
                'data': serializer.data
            },
            status_code=status.HTTP_200_OK
        )
from rest_framework.views import APIView
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.throttling import ScopedRateThrottle
from rest_framework import generics
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.exceptions import NotFound, PermissionDenied
from rest_framework.permissions import IsAuthenticated, IsAdminUser

from accounts.models import Profile
from accounts.serializers import UserRegistrationSerializer, UserLoginSerializer, UserPasswordUpdateSerializer, ProfileUpdateSerializer, ProfileAdminUpdateSerializer, ProfileSerializer
from accounts.permissions import IsAuthenticatedOrAdmin, IsOwnerOfProfile
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
                    result={"message": "User registered successfully."},
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
        return self.request.user

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
        operation_description="Update a user's profile by user_id. Only accessible to superusers and admin or the user themselves.",
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
        operation_description="Update a user's profile by user_id. Only accessible to superusers and admin or the user themselves.",
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
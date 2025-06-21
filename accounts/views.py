from rest_framework.views import APIView
from rest_framework import status
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.throttling import ScopedRateThrottle

from accounts.serializers import UserRegistrationSerializer, UserLoginSerializer, UserPasswordUpdateSerializer
from accounts.permissions import IsAuthenticatedOrAdmin
from myproject.utils import api_response, blacklist_user_tokens

from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi

class RegisterView(APIView):
    permission_classes = [AllowAny]

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
    permission_classes = [IsAuthenticatedOrAdmin]

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
from core.serializers import *
from core.models import *
from core.paginations import DefaultPagination
from core.permissions import OwnsObjectOrAdmin
from myproject.utils import api_response

from rest_framework import generics, status
from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework.permissions import IsAuthenticated
from rest_framework.exceptions import ValidationError, PermissionDenied

from drf_yasg.utils import swagger_auto_schema
from drf_yasg import openapi

from django.db import IntegrityError, transaction
from django.http import Http404


class HashTagListCreateAPI(generics.ListCreateAPIView):
    serializer_class = HashTagCreateUpdateSerializer
    pagination_class = DefaultPagination
    queryset = HashTag.objects.all()
    authentication_classes = [JWTAuthentication]
    permission_classes = [IsAuthenticated]
    http_method_names = ['get', 'post']

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
        request_body=HashTagCreateUpdateSerializer,
        responses={
            201: openapi.Response(
                description="Successfully created a hashtag.",
                schema=HashTagCreateUpdateSerializer,
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
            queryset = self.filter_queryset(self.get_queryset())
            page = self.paginate_queryset(queryset)
            if page is not None:
                serializer = self.get_serializer(page, many=True)
                return self.get_paginated_response(serializer.data)
            serializer = self.get_serializer(queryset, many=True)

            return api_response(
                is_success=True,
                result={
                    "message": "Successfully retrieved hashtags.",
                    "data": request.data
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
                schema=HashTagCreateUpdateSerializer(many=True),
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



class HashTagRetrieveUpdateDestroy(generics.RetrieveUpdateDestroyAPIView):
    serializer_class = HashTagCreateUpdateSerializer
    pagination_class = DefaultPagination
    queryset = HashTag.objects.all()
    authentication_classes = [JWTAuthentication]
    permission_classes = []
    http_method_names = ['get', 'patch', 'delete']

    def get_permissions(self):
        if self.request.method == 'PATCH' or self.request.method == 'DELETE':
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

        except Http404:
            return api_response(
                is_success=False,
                error_message="Hashtag not found.",
                status_code=status.HTTP_404_NOT_FOUND
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        responses={
            200: openapi.Response(
                description="Hashtag retrieved successfully",
                schema=HashTagCreateUpdateSerializer()
            ),
            404: 'Hashtag not found',
            500: 'Internal Server Error.'
        },
        tags=["HashTag"]
    )
    def get(self, request, *args, **kwargs):
        return super().get(request, *args, **kwargs)

    def partial_update(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            serializer = self.get_serializer(instance, data=request.data, partial=True)
            serializer.is_valid(raise_exception=True)
            serializer.save()
            return api_response(
                is_success=True,
                result={
                    "message": "Hashtag updated successfully.",
                    "data": serializer.data
                },
                status_code=status.HTTP_200_OK
            )

        except Http404:
            return api_response(
                is_success=False,
                error_message="Hashtag not found.",
                status_code=status.HTTP_404_NOT_FOUND
            )

        except PermissionDenied:
            return api_response(
                is_success=False,
                error_message="You do not have permission to perform this action.",
                status_code=status.HTTP_403_FORBIDDEN
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
            )


    @swagger_auto_schema(
        request_body=HashTagCreateUpdateSerializer,
        responses={
            200: openapi.Response(
                description="Hashtag updated successfully",
                schema=HashTagCreateUpdateSerializer()
            ),
            403: 'Permission denied',
            404: 'Hashtag not found',
            400: 'Validation error',
            500: 'Internal Server Error.'
        },
        tags=["HashTag"]
    )
    def patch(self, request, *args, **kwargs):
        return super().patch(request, *args, **kwargs)


    def destroy(self, request, *args, **kwargs):
        try:
            instance = self.get_object()
            instance.delete()
            return api_response(
                is_success=True,
                result={"message": f"Hashtag deleted successfully."},
                status_code=status.HTTP_200_OK
            )

        except Http404:
            return api_response(
                is_success=False,
                error_message="Hashtag not found.",
                status_code=status.HTTP_404_NOT_FOUND
            )

        except PermissionDenied:
            return api_response(
                is_success=False,
                error_message="You do not have permission to perform this action.",
                status_code=status.HTTP_403_FORBIDDEN
            )

        except Exception as e:
            return api_response(
                is_success=False,
                error_message=str(e),
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    @swagger_auto_schema(
        responses={
            200: 'Hashtag deleted successfully',
            403: 'Permission denied',
            404: 'Hashtag not found',
            500: 'Internal Server Error.'
        },
        tags=["HashTag"]
    )
    def delete(self, request, *args, **kwargs):
        return super().delete(request, *args, **kwargs)
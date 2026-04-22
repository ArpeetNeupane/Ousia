from rest_framework import status
from rest_framework.exceptions import PermissionDenied, NotAuthenticated, Throttled, NotFound
from rest_framework.views import exception_handler

from myproject.utils import api_response

from django.core.exceptions import ValidationError as DjangoValidationError
from django.http import Http404


def custom_exception_handler(exc, context):
    #handling Django ValidationError for errors from model methods
    if isinstance(exc, DjangoValidationError):
        detail = exc.message_dict if hasattr(exc, 'message_dict') else exc.messages
        return api_response(
            is_success=False,
            error_message=detail,
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    if isinstance(exc, Throttled):
        return api_response(
            is_success=False,
            error_message="Please wait for some time before trying again.",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    if isinstance(exc, (NotAuthenticated)):
        return api_response(
            is_success=False,
            error_message=str(exc),
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    if isinstance(exc, (PermissionDenied)):
        return api_response(
            is_success=False,
            error_message=str(exc),
            status_code=status.HTTP_403_FORBIDDEN,
        )

    if isinstance(exc, (NotFound, Http404)):
        return api_response(
            is_success=False,
            error_message="Sorry! The object you're searching for doesn't exist.",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    response = exception_handler(exc, context)

    if response is not None:
        return api_response(
            is_success=False,
            error_message=response.data,
            status_code=response.status_code
        )

    return api_response(
        is_success=False,
        error_message=str(exc),
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR
    )
from rest_framework import status
from rest_framework.exceptions import PermissionDenied, NotAuthenticated, Throttled
from rest_framework.views import exception_handler

from myproject.utils import api_response

def custom_exception_handler(exc, context):
    if isinstance(exc, Throttled):
        return api_response(
            is_success=False,
            error_message="Too many requests. Please wait for some time before trying again.",
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
        )

    if isinstance(exc, (PermissionDenied, NotAuthenticated)):
        return api_response(
            is_success=False,
            error_message=str(exc),
            status_code=status.HTTP_403_FORBIDDEN,
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
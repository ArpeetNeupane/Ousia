from rest_framework.response import Response
from rest_framework import status
from rest_framework.exceptions import Throttled, NotAuthenticated, PermissionDenied
from rest_framework.views import exception_handler
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken

def api_response(
    result=None,
    is_success=False,
    error_message=None,
    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
):
    return Response(
        {
            "StatusCode": status_code,
            "IsSuccess": is_success,
            "ErrorMessage": error_message if error_message else [],
            "Result": result,
        },
        status=status_code,
    )


def blacklist_user_tokens(user):
    tokens = OutstandingToken.objects.filter(user=user)
    for token in tokens:
        BlacklistedToken.objects.get_or_create(token=token)

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
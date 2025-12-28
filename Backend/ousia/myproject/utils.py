from rest_framework.response import Response
from rest_framework import status
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
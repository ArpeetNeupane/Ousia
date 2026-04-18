from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken

def api_response(
    result=None,
    is_success=False,
    error_message=None,
    status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
):
    """
    Creates a standardized API response structure.

    Ensures all responses follow a consistent format with:
    - StatusCode
    - IsSuccess
    - ErrorMessage
    - Result

    Args:
        result (Any, optional): Payload data to return in the response.
        is_success (bool, optional): Indicates if the request was successful.
        error_message (str | list | None, optional): Error message(s) if any.
        status_code (int, optional): HTTP status code for the response.

    Returns:
        Response: DRF Response object with standardized structure.
    """

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
    """
    Blacklists all outstanding JWT tokens for a given user.

    Fetches all active (outstanding) tokens associated with the user
    and adds them to the blacklist to prevent further use.

    Typically used during logout or forced session invalidation.

    Args:
        user (User): The user whose tokens should be blacklisted.

    Returns:
        None
    """
    
    tokens = OutstandingToken.objects.filter(user=user)
    for token in tokens:
        BlacklistedToken.objects.get_or_create(token=token)
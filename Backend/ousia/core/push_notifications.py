import logging
from django.conf import settings

from accounts.models import UserDeviceToken

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
except Exception:
    firebase_admin = None
    credentials = None
    messaging = None

logger = logging.getLogger(__name__)

RESERVED_FCM_DATA_KEYS = {
    'from',
    'message_type',
    'collapse_key',
}


def _init_firebase_admin():
    if firebase_admin is None or credentials is None:
        return False

    if firebase_admin._apps:
        return True

    service_account_path = (settings.FIREBASE_SERVICE_ACCOUNT_FILE or '').strip()
    if not service_account_path:
        return False

    cred = credentials.Certificate(service_account_path)
    firebase_admin.initialize_app(cred)
    return True


def _clean_data(data):
    cleaned = {}
    for key, value in (data or {}).items():
        key_str = str(key)
        key_lower = key_str.lower()

        # Firebase rejects reserved keys in message.data. Prefix to preserve value safely.
        if key_lower in RESERVED_FCM_DATA_KEYS or key_lower.startswith('google.'):
            key_str = f'x_{key_str}'

        cleaned[key_str] = '' if value is None else str(value)
    return cleaned


def send_push_to_user_id(user_id, title, body, data=None):
    logger.info(f"[PUSH] Attempting to send push to user_id={user_id}, title={title}, body={body[:50] if body else 'N/A'}")
    
    if not _init_firebase_admin():
        logger.error(f"[PUSH] Firebase admin not initialized for user_id={user_id}")
        return 0

    tokens = list(
        UserDeviceToken.objects.filter(user_id=user_id, is_active=True)
        .values_list('token', flat=True)
        .distinct()
    )
    
    logger.info(f"[PUSH] Found {len(tokens)} active token(s) for user_id={user_id}")
    
    if not tokens:
        logger.warning(f"[PUSH] No active tokens found for user_id={user_id}")
        return 0

    android_config = messaging.AndroidConfig(
        priority='high',
        notification=messaging.AndroidNotification(
            channel_id='ousia_high_importance',
            sound='default',
        ),
    )

    apns_config = messaging.APNSConfig(
        headers={'apns-priority': '10'},
        payload=messaging.APNSPayload(
            aps=messaging.Aps(
                sound='default',
            )
        ),
    )

    message = messaging.MulticastMessage(
        notification=messaging.Notification(title=title, body=body),
        data=_clean_data(data),
        tokens=tokens,
        android=android_config,
        apns=apns_config,
    )

    logger.info(f"[PUSH] Sending Firebase message for user_id={user_id} with {len(tokens)} token(s)")
    
    try:
        response = messaging.send_each_for_multicast(message)
        logger.info(f"[PUSH] Firebase response for user_id={user_id}: success_count={response.success_count}, failure_count={response.failure_count}")
    except Exception as e:
        logger.exception(f"[PUSH] Firebase send failed for user_id={user_id}: {str(e)}")
        return 0

    # Deactivate invalid/unregistered tokens.
    invalid_tokens = []
    for idx, send_response in enumerate(response.responses):
        if send_response.success:
            logger.debug(f"[PUSH] Token {idx}: success")
            continue
        exc = send_response.exception
        code = getattr(exc, 'code', '') if exc else ''
        code_str = str(code)
        err_str = str(exc or '')
        err_lower = err_str.lower()
        code_lower = code_str.lower()
        logger.warning(f"[PUSH] Token {idx} failed with code={code_str}, error={err_str}")

        # Only deactivate tokens for token-specific failures.
        if (
            'unregistered' in code_lower
            or 'registration-token-not-registered' in err_lower
            or 'invalid-registration-token' in err_lower
        ):
            invalid_tokens.append(tokens[idx])

    if invalid_tokens:
        logger.info(f"[PUSH] Deactivating {len(invalid_tokens)} invalid token(s) for user_id={user_id}")
        UserDeviceToken.objects.filter(token__in=invalid_tokens).update(is_active=False)

    logger.info(f"[PUSH] Push send completed for user_id={user_id}: {response.success_count} successful")
    return response.success_count


def send_push_to_user(user, title, body, data=None):
    if not user:
        return 0
    return send_push_to_user_id(user.id, title, body, data=data)

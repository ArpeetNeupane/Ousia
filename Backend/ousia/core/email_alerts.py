import logging

from django.template.loader import render_to_string
from django.utils.html import strip_tags


logger = logging.getLogger(__name__)


def send_moderation_parent_email(
    *,
    user,
    content_type,
    moderation_status,
    reason,
    score,
    label,
    model_used,
):
    if not user or not getattr(user, 'email', None):
        return False

    status_lower = (moderation_status or '').lower()
    if status_lower == 'blocked':
        status_title = 'Blocked'
        status_badge_color = '#dc2626'
        status_message = (
            f"A {content_type} attempt was blocked by Ousia safety checks and was not published."
        )
    else:
        status_title = 'Pending Review'
        status_badge_color = '#d97706'
        status_message = (
            f"A {content_type} attempt was flagged by Ousia safety checks and is pending review."
        )

    html_message = render_to_string(
        'accounts/emails/moderation_alert.html',
        {
            'username': user.username,
            'content_type': content_type,
            'status_title': status_title,
            'status_badge_color': status_badge_color,
            'status_message': status_message,
            'reason': reason or 'No reason provided by the moderation model.',
            'score': f"{float(score):.3f}" if score is not None else 'N/A',
            'label': label or 'unknown',
            'model_used': model_used or 'unknown',
        },
    )
    plain_message = strip_tags(html_message)

    try:
        user.send_email_to_user(
            subject=f'Ousia Safety Alert: {content_type.title()} {status_title}',
            message=plain_message,
            html_message=html_message,
        )
        return True
    except Exception:
        logger.exception(
            'Failed to send moderation parent email for user_id=%s and content_type=%s',
            getattr(user, 'id', None),
            content_type,
        )
        return False

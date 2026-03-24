from asgiref.sync import async_to_sync, sync_to_async
from channels.layers import get_channel_layer

from core.models import Notification


def serialize_notification(notification):
    return {
        'id': notification.id,
        'notification_type': notification.notification_type,
        'title': notification.title,
        'body': notification.body,
        'data': notification.data,
        'is_read': notification.is_read,
        'created_at': notification.created_at.isoformat() if notification.created_at else None,
        'recipient': notification.recipient_id,
        'actor': notification.actor_id,
        'actor_username': notification.actor.username if notification.actor else None,
    }


def push_realtime_notification(notification):
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    async_to_sync(channel_layer.group_send)(
        f'notifications_user_{notification.recipient_id}',
        {
            'type': 'notification_event',
            'notification': serialize_notification(notification),
        },
    )


async def push_realtime_notification_async(notification, actor_username=None):
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    payload = {
        'id': notification.id,
        'notification_type': notification.notification_type,
        'title': notification.title,
        'body': notification.body,
        'data': notification.data,
        'is_read': notification.is_read,
        'created_at': notification.created_at.isoformat() if notification.created_at else None,
        'recipient': notification.recipient_id,
        'actor': notification.actor_id,
        'actor_username': actor_username,
    }

    await channel_layer.group_send(
        f'notifications_user_{notification.recipient_id}',
        {
            'type': 'notification_event',
            'notification': payload,
        },
    )


def create_notification(recipient, actor, notification_type, title, body, data=None):
    if not recipient:
        return None

    #skipping self notifications for cleaner UX.
    if actor and recipient.id == actor.id:
        return None

    notification = Notification.objects.create(
        recipient=recipient,
        actor=actor,
        notification_type=notification_type,
        title=title,
        body=body,
        data=data or {},
    )
    push_realtime_notification(notification)
    return notification


def create_notification_by_ids(recipient_id, actor_id, notification_type, title, body, data=None):
    if not recipient_id:
        return None

    if actor_id and recipient_id == actor_id:
        return None

    notification = Notification.objects.create(
        recipient_id=recipient_id,
        actor_id=actor_id,
        notification_type=notification_type,
        title=title,
        body=body,
        data=data or {},
    )
    push_realtime_notification(notification)
    return notification


async def acreate_notification_by_ids(
    recipient_id,
    actor_id,
    notification_type,
    title,
    body,
    data=None,
    actor_username=None,
):
    if not recipient_id:
        return None

    if actor_id and recipient_id == actor_id:
        return None

    notification = await sync_to_async(Notification.objects.create)(
        recipient_id=recipient_id,
        actor_id=actor_id,
        notification_type=notification_type,
        title=title,
        body=body,
        data=data or {},
    )
    await push_realtime_notification_async(notification, actor_username=actor_username)
    return notification

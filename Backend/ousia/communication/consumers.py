import json

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async

from django.core.exceptions import ValidationError

from accounts.models import User
from communication.models import Conversation, Message, ConversationParticipant
from communication.serializers import MessageCreateSerializer
from communication.utils import moderate_message
from core.models import Notification
from core.notifications import acreate_notification_by_ids
from core.email_alerts import send_moderation_parent_email
from core.utils.nsfw_classifier import NSFWVerdict


class ChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for handling real-time chat messages.
    Each conversation has its own channel group.
    """

    async def connect(self):
        self.conversation_id = str(self.scope['url_route']['kwargs']['conversation_id'])
        self.room_group_name = f'chat_{self.conversation_id}'
        self.user = self.scope['user']

        if not self.user.is_authenticated:
            await self.close()
            return

        is_participant = await self.check_user_is_participant()
        if not is_participant:
            await self.close()
            return

        await self.accept()

        await self.send(text_data=json.dumps({
            'type': 'connection_established',
            'message': 'Connected to chat'
        }))

        try:
            history = await self.get_message_history()
            await self.send(text_data=json.dumps({
                'type': 'message_history',
                'messages': history
            }))
        except Exception as e:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Failed to load history'
            }))

        try:
            if self.channel_layer:
                await self.channel_layer.group_add(
                    self.room_group_name,
                    self.channel_name
                )
        except Exception:
            await self.send(text_data=json.dumps({
                'type': 'error',
                'message': 'Real-time broadcast unavailable'
            }))

        try:
            await self.mark_conversation_as_read()
        except Exception:
            pass

    async def disconnect(self, close_code):
        """Called when WebSocket connection is closed"""
        #leaving room group
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

    #this is like a traffic controller for different types of messages
    async def receive(self, text_data):
        """
        Called when we receive a message from WebSocket.
        Handles different message types: send_message, edit_message, delete_message, typing_indicator
        """
        try:
            data = json.loads(text_data)
            message_action = data.get('action')

            if message_action == 'send_message':
                await self.handle_send_message(data)
            elif message_action == 'edit_message':
                await self.handle_edit_message(data)
            elif message_action == 'delete_message':
                await self.handle_delete_message(data)
            elif message_action == 'typing_indicator':
                await self.handle_typing_indicator(data)
            else:
                await self.send_error('Unknown action')

        except json.JSONDecodeError:
            await self.send_error('Invalid JSON')
        except Exception as e:
            await self.send_error(str(e))

    async def handle_send_message(self, data):
        """Handle sending a new message"""
        content = data.get('content', '').strip()
        message_type = data.get('message_type', 'text')
        file_url = data.get('file_attachment_public_url')
        reply_to_id = data.get('reply_to')

        if not content and message_type in ['text', 'system']:
            await self.send_error('Content is required for text messages')
            return
        
        #checking message content for inappropriate material
        if message_type in ['text', 'system'] and content:
            mod_result = moderate_message(content)

            if mod_result.verdict in [NSFWVerdict.BLOCK, NSFWVerdict.REVIEW]:
                moderation_status = 'blocked' if mod_result.verdict == NSFWVerdict.BLOCK else 'pending_review'
                await self.send_parent_moderation_alert(
                    content_type='message',
                    moderation_status=moderation_status,
                    reason=mod_result.reason,
                    score=mod_result.score,
                    label=mod_result.label,
                    model_used=mod_result.model_used,
                )

            if mod_result.verdict == NSFWVerdict.BLOCK:
                await self.send_error('This message contains inappropriate content and cannot be sent.')
                return

        #saving message to database
        message = await self.create_message(
            content=content,
            message_type=message_type,
            file_url=file_url,
            reply_to_id=reply_to_id
        )

        if message:
            #serializing the message
            message_data = await self.serialize_message(message)

            await self.notify_recipients_for_message(message, content, message_type)

            message_data_updated = json.loads(json.dumps(message_data, default=str))

            #broadcasting to room group
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_message',
                    'message': message_data_updated
                }
            )

    async def handle_edit_message(self, data):
        """Handle editing an existing message"""
        message_id = data.get('message_id')
        new_content = data.get('content', '').strip()

        if not message_id or not new_content:
            await self.send_error('Message ID and content are required')
            return

        #updating message in database
        message = await self.update_message(message_id, new_content)

        if message:
            message_data = await self.serialize_message(message)

            message_data_updated = json.loads(json.dumps(message_data, default=str))

            #broadcasting edit to room group
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'message_edited',
                    'message': message_data_updated
                }
            )

    async def handle_delete_message(self, data):
        """Handle soft-deleting a message"""
        message_id = data.get('message_id')

        if not message_id:
            await self.send_error('Message ID is required')
            return

        #soft deleting message
        success = await self.delete_message(message_id)

        if success:
            #broadcasting deletion to room group
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'message_deleted',
                    'message_id': str(message_id)
                }
            )

    async def handle_typing_indicator(self, data):
        """Handle typing indicator (user is typing...)"""
        is_typing = data.get('is_typing', False)

        #broadcasting typing status to room group (except sender)
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'user_typing',
                'user_id': str(self.user.id),
                'username': self.user.username,
                'is_typing': is_typing
            }
        )

    #event handlers (called by group_send)
    async def chat_message(self, event):
        """Send message to WebSocket"""
        print(f"BROADCAST RECEIVED: {event['message']['content']}")
        await self.mark_conversation_as_read()
        await self.send(text_data=json.dumps({
            'type': 'new_message',
            'message': event['message']
        }))

    async def message_edited(self, event):
        """Send edited message to WebSocket"""
        await self.send(text_data=json.dumps({
            'type': 'message_edited',
            'message': event['message']
        }))

    async def message_deleted(self, event):
        """Send message deletion notification to WebSocket"""
        await self.send(text_data=json.dumps({
            'type': 'message_deleted',
            'message_id': event['message_id']
        }))

    async def user_typing(self, event):
        """Send typing indicator to WebSocket (skip for sender)"""
        #not send typing indicator back to the sender
        if str(self.user.id) != event['user_id']:
            await self.send(text_data=json.dumps({
                'type': 'typing_indicator',
                'user_id': event['user_id'],
                'username': event['username'],
                'is_typing': event['is_typing']
            }))

    #database operations (sync methods called asynchronously)
    @database_sync_to_async
    def check_user_is_participant(self):
        """Verify user is a participant of the conversation"""
        try:
            participant = ConversationParticipant.objects.filter(
                user=self.user,
                conversation_id=self.conversation_id,
                deleted_for_user=False
            ).exists()
            
            #also checking conversation is not deleted
            conversation = Conversation.objects.filter(
                id=self.conversation_id,
                is_deleted=False
            ).exists()
            
            return participant and conversation
        except Exception:
            return False

    @database_sync_to_async
    def create_message(self, content, message_type, file_url, reply_to_id):
        """Create a new message in the database"""
        try:
            message = Message.objects.create(
                conversation_id=self.conversation_id,
                sender=self.user,
                content=content,
                message_type=message_type,
                file_attachment_public_url=file_url,
                reply_to_id=reply_to_id 
            )

            if reply_to_id:
                try:
                    reply_to = Message.objects.get(id=reply_to_id)
                    message.reply_to = reply_to
                except Message.DoesNotExist:
                    pass  #ignoring if reply_to message doesn't exist

            message.save()
            
            #updating conversation's updated_at timestamp
            conversation = Conversation.objects.get(id=self.conversation_id)
            conversation.save(clean=False)
            
            return message
        except ValidationError as e:
            return None
        except Exception as e:
            return None

    @database_sync_to_async
    def update_message(self, message_id, new_content):
        """Update an existing message"""
        try:
            message = Message.objects.get(
                id=message_id,
                sender=self.user,  #only sender can edit
                conversation_id=self.conversation_id,
                is_deleted=False
            )
            message.content = new_content
            message.is_edited = True
            message.save()
            return message
        except Message.DoesNotExist:
            return None

    @database_sync_to_async
    def delete_message(self, message_id):
        """Soft delete a message"""
        try:
            message = Message.objects.get(
                id=message_id,
                sender=self.user,  #only sender can delete
                conversation_id=self.conversation_id
            )
            message.soft_delete()
            return True
        except Message.DoesNotExist:
            return False

    @database_sync_to_async
    def serialize_message(self, message):
        """Serialize message object to dictionary"""
        serializer = MessageCreateSerializer(message)
        return json.loads(json.dumps(dict(serializer.data), default=str))

    @database_sync_to_async
    def get_notification_recipient_ids(self):
        return list(
            ConversationParticipant.objects.filter(
                conversation_id=self.conversation_id,
                deleted_for_user=False,
            ).exclude(user_id=self.user.id).values_list('user_id', flat=True)
        )

    @database_sync_to_async
    def send_parent_moderation_alert(self, content_type, moderation_status, reason, score, label, model_used):
        send_moderation_parent_email(
            user=self.user,
            content_type=content_type,
            moderation_status=moderation_status,
            reason=reason,
            score=score,
            label=label,
            model_used=model_used,
        )

    async def notify_recipients_for_message(self, message, content, message_type):
        recipient_ids = await self.get_notification_recipient_ids()

        for recipient_id in recipient_ids:
            await acreate_notification_by_ids(
                recipient_id=recipient_id,
                actor_id=self.user.id,
                notification_type=Notification.NotificationTypes.MESSAGE,
                title='New message',
                body=(
                    f"{self.user.username}: {content[:80]}"
                    if content
                    else f"{self.user.username} sent a {message_type} message."
                ),
                data={
                    'conversation_id': str(self.conversation_id),
                    'message_id': str(message.id),
                    'message_type': message.message_type,
                },
                actor_username=self.user.username,
            )

    async def send_error(self, error_message):
        """Send error message to WebSocket"""
        await self.send(text_data=json.dumps({
            'type': 'error',
            'message': error_message
        }))
    
    @database_sync_to_async
    def get_message_history(self, limit=50):
        try:
            messages = Message.objects.filter(
                conversation_id=self.conversation_id,
                is_deleted=False
            ).select_related('sender').order_by('-created_at')[:limit]
            
            serializer = MessageCreateSerializer(reversed(list(messages)), many=True)
            return json.loads(json.dumps(list(serializer.data), default=str))
        except Exception:
            return []
    
    @database_sync_to_async
    def mark_conversation_as_read(self):
        """Update the last_read_at timestamp for this participant"""
        try:
            from django.utils import timezone
            ConversationParticipant.objects.filter(
                conversation_id=self.conversation_id,
                user=self.user
            ).update(last_read_at=timezone.now())
        except Exception:
            pass


class NotificationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.user = self.scope['user']
        if not self.user.is_authenticated:
            await self.close()
            return

        self.group_name = f'notifications_user_{self.user.id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def notification_event(self, event):
        await self.send(text_data=json.dumps({
            'type': 'notification',
            'notification': event['notification'],
        }))
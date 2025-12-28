import json

from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async

from django.core.exceptions import ValidationError

from communication.models import Conversation, Message, ConversationParticipant
from communication.serializers import MessageCreateSerializer


class ChatConsumer(AsyncWebsocketConsumer):
    """
    WebSocket consumer for handling real-time chat messages.
    Each conversation has its own channel group.
    """

    async def connect(self):
        """Called when WebSocket connection is established"""
        self.conversation_id = self.scope['url_route']['kwargs']['conversation_id']
        self.room_group_name = f'chat_{self.conversation_id}'
        self.user = self.scope['user']

        # # Reject unauthenticated users
        # if not self.user.is_authenticated:
        #     await self.close()
        #     return

        # # Verify user is participant of this conversation
        # is_participant = await self.check_user_is_participant()
        # if not is_participant:
        #     await self.close()
        #     return

        # Join room group
        await self.channel_layer.group_add(
            self.room_group_name,
            self.channel_name
        )

        await self.accept()

        # Optional: Send connection confirmation
        await self.send(text_data=json.dumps({
            'type': 'connection_established',
            'message': 'Connected to chat'
        }))

    async def disconnect(self, close_code):
        """Called when WebSocket connection is closed"""
        # Leave room group
        await self.channel_layer.group_discard(
            self.room_group_name,
            self.channel_name
        )

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

        # Save message to database
        message = await self.create_message(
            content=content,
            message_type=message_type,
            file_url=file_url,
            reply_to_id=reply_to_id
        )

        if message:
            # Serialize the message
            message_data = await self.serialize_message(message)

            # Broadcast to room group
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'chat_message',
                    'message': message_data
                }
            )

    async def handle_edit_message(self, data):
        """Handle editing an existing message"""
        message_id = data.get('message_id')
        new_content = data.get('content', '').strip()

        if not message_id or not new_content:
            await self.send_error('Message ID and content are required')
            return

        # Update message in database
        message = await self.update_message(message_id, new_content)

        if message:
            message_data = await self.serialize_message(message)

            # Broadcast edit to room group
            await self.channel_layer.group_send(
                self.room_group_name,
                {
                    'type': 'message_edited',
                    'message': message_data
                }
            )

    async def handle_delete_message(self, data):
        """Handle soft-deleting a message"""
        message_id = data.get('message_id')

        if not message_id:
            await self.send_error('Message ID is required')
            return

        # Soft delete message
        success = await self.delete_message(message_id)

        if success:
            # Broadcast deletion to room group
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

        # Broadcast typing status to room group (except sender)
        await self.channel_layer.group_send(
            self.room_group_name,
            {
                'type': 'user_typing',
                'user_id': str(self.user.id),
                'username': self.user.username,
                'is_typing': is_typing
            }
        )

    # Event handlers (called by group_send)
    async def chat_message(self, event):
        """Send message to WebSocket"""
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
        # Don't send typing indicator back to the sender
        if str(self.user.id) != event['user_id']:
            await self.send(text_data=json.dumps({
                'type': 'typing_indicator',
                'user_id': event['user_id'],
                'username': event['username'],
                'is_typing': event['is_typing']
            }))

    # Database operations (sync methods called asynchronously)
    @database_sync_to_async
    def check_user_is_participant(self):
        """Verify user is a participant of the conversation"""
        try:
            participant = ConversationParticipant.objects.filter(
                user=self.user,
                conversation_id=self.conversation_id,
                deleted_for_user=False
            ).exists()
            
            # Also check conversation is not deleted
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
            message = Message(
                conversation_id=self.conversation_id,
                sender=self.user,
                content=content,
                message_type=message_type,
                file_attachment_public_url=file_url
            )

            if reply_to_id:
                try:
                    reply_to = Message.objects.get(id=reply_to_id)
                    message.reply_to = reply_to
                except Message.DoesNotExist:
                    pass  # Ignore if reply_to message doesn't exist

            message.save()
            
            # Update conversation's updated_at timestamp
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
                sender=self.user,  # Only sender can edit
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
                sender=self.user,  # Only sender can delete
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
        return serializer.data

    async def send_error(self, error_message):
        """Send error message to WebSocket"""
        await self.send(text_data=json.dumps({
            'type': 'error',
            'message': error_message
        }))
from __future__ import annotations

from datetime import date
from types import SimpleNamespace
from unittest.mock import AsyncMock, patch

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from channels.testing import WebsocketCommunicator
from django.test import TransactionTestCase, override_settings
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import RoleEnum, User
from communication.models import Conversation, Message
from core.utils.nsfw_classifier import NSFWVerdict
IN_MEMORY_CHANNEL_LAYERS = {
	"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}
}


def _access_token_for(user: User) -> str:
	return str(RefreshToken.for_user(user).access_token)


@override_settings(CHANNEL_LAYERS=IN_MEMORY_CHANNEL_LAYERS)
class ChatConsumerWebsocketTests(TransactionTestCase):
	def setUp(self):
		self.user1 = User.objects.create_user(
			username="chatuser1",
			email="c1@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 1, 1),
			role=RoleEnum.USER,
		)
		self.user2 = User.objects.create_user(
			username="chatuser2",
			email="c2@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 1, 2),
			role=RoleEnum.USER,
		)
		self.user3 = User.objects.create_user(
			username="chatuser3",
			email="c3@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 1, 3),
			role=RoleEnum.USER,
		)

		self.conversation = Conversation.objects.create()
		self.conversation.participants.add(self.user1, self.user2)

		self.token1 = _access_token_for(self.user1)
		self.token2 = _access_token_for(self.user2)
		self.token3 = _access_token_for(self.user3)

	def _chat_path(self, *, token: str | None) -> str:
		qs = f"?token={token}" if token else ""
		return f"/ws/chat/{self.conversation.id}/{qs}"

	async def _connect_and_drain_initial(self, communicator: WebsocketCommunicator) -> None:
		connected, _ = await communicator.connect()
		self.assertTrue(connected)
		msg1 = await communicator.receive_json_from(timeout=2)
		self.assertEqual(msg1.get("type"), "connection_established")
		msg2 = await communicator.receive_json_from(timeout=2)
		self.assertEqual(msg2.get("type"), "message_history")

	def test_connect_rejects_unauthenticated(self):
		async def _run():
			from myproject.asgi import application as asgi_app

			communicator = WebsocketCommunicator(asgi_app, self._chat_path(token=None))
			connected, _ = await communicator.connect()
			self.assertFalse(connected)

		async_to_sync(_run)()

	def test_connect_rejects_non_participant(self):
		async def _run():
			from myproject.asgi import application as asgi_app

			communicator = WebsocketCommunicator(asgi_app, self._chat_path(token=self.token3))
			connected, _ = await communicator.connect()
			self.assertFalse(connected)

		async_to_sync(_run)()

	@patch("communication.consumers.acreate_notification_by_ids", new_callable=AsyncMock)
	@patch("communication.consumers.moderate_message")
	def test_send_message_broadcasts_and_persists(self, mock_moderate, _mock_notify):
		mock_moderate.return_value = SimpleNamespace(
			verdict=NSFWVerdict.PASS,
			score=0.0,
			label="clean",
			model_used="none",
			reason="ok",
		)

		async def _run():
			from myproject.asgi import application as asgi_app

			comm1 = WebsocketCommunicator(asgi_app, self._chat_path(token=self.token1))
			comm2 = WebsocketCommunicator(asgi_app, self._chat_path(token=self.token2))

			await self._connect_and_drain_initial(comm1)
			await self._connect_and_drain_initial(comm2)

			await comm1.send_json_to({"action": "send_message", "content": "hello", "message_type": "text"})

			#sender receives its own broadcast
			ev1 = await comm1.receive_json_from(timeout=2)
			self.assertEqual(ev1.get("type"), "new_message")
			self.assertEqual(ev1["message"]["content"], "hello")

			#other participant receives broadcast
			ev2 = await comm2.receive_json_from(timeout=2)
			self.assertEqual(ev2.get("type"), "new_message")
			self.assertEqual(ev2["message"]["content"], "hello")

			await comm1.disconnect()
			await comm2.disconnect()

		async_to_sync(_run)()

		self.assertTrue(
			Message.objects.filter(conversation=self.conversation, sender=self.user1, content="hello").exists()
		)

	def test_typing_indicator_sent_to_other_user_only(self):
		async def _run():
			from myproject.asgi import application as asgi_app

			comm1 = WebsocketCommunicator(asgi_app, self._chat_path(token=self.token1))
			comm2 = WebsocketCommunicator(asgi_app, self._chat_path(token=self.token2))

			await self._connect_and_drain_initial(comm1)
			await self._connect_and_drain_initial(comm2)

			await comm1.send_json_to({"action": "typing_indicator", "is_typing": True})

			# receiver gets typing event
			ev = await comm2.receive_json_from(timeout=2)
			self.assertEqual(ev.get("type"), "typing_indicator")
			self.assertEqual(ev.get("user_id"), str(self.user1.id))
			self.assertTrue(ev.get("is_typing"))

			#sender should not receive its own typing indicator
			nothing = await comm1.receive_nothing(timeout=0.5)
			self.assertTrue(nothing)

			await comm1.disconnect()
			await comm2.disconnect()

		async_to_sync(_run)()

	@patch("communication.consumers.acreate_notification_by_ids", new_callable=AsyncMock)
	@patch("communication.consumers.moderate_message")
	def test_edit_and_delete_message_broadcasts(self, mock_moderate, _mock_notify):
		mock_moderate.return_value = SimpleNamespace(
			verdict=NSFWVerdict.PASS,
			score=0.0,
			label="clean",
			model_used="none",
			reason="ok",
		)

		async def _run():
			from myproject.asgi import application as asgi_app

			comm1 = WebsocketCommunicator(asgi_app, self._chat_path(token=self.token1))
			comm2 = WebsocketCommunicator(asgi_app, self._chat_path(token=self.token2))

			await self._connect_and_drain_initial(comm1)
			await self._connect_and_drain_initial(comm2)

			await comm1.send_json_to({"action": "send_message", "content": "first", "message_type": "text"})
			ev1 = await comm1.receive_json_from(timeout=2)
			_ = await comm2.receive_json_from(timeout=2)

			message_id = ev1["message"]["id"]

			await comm1.send_json_to({"action": "edit_message", "message_id": message_id, "content": "edited"})
			edited1 = await comm1.receive_json_from(timeout=2)
			edited2 = await comm2.receive_json_from(timeout=2)
			self.assertEqual(edited1.get("type"), "message_edited")
			self.assertEqual(edited2.get("type"), "message_edited")
			self.assertEqual(edited1["message"]["content"], "edited")

			await comm1.send_json_to({"action": "delete_message", "message_id": message_id})
			del1 = await comm1.receive_json_from(timeout=2)
			del2 = await comm2.receive_json_from(timeout=2)
			self.assertEqual(del1.get("type"), "message_deleted")
			self.assertEqual(del2.get("type"), "message_deleted")
			self.assertEqual(del1.get("message_id"), str(message_id))

			await comm1.disconnect()
			await comm2.disconnect()

		async_to_sync(_run)()

		msg = Message.objects.get(conversation=self.conversation, sender=self.user1)
		self.assertTrue(msg.is_deleted)
		self.assertEqual(msg.content, "This message was deleted")


@override_settings(CHANNEL_LAYERS=IN_MEMORY_CHANNEL_LAYERS)
class NotificationConsumerWebsocketTests(TransactionTestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="notifuser",
			email="n@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 2, 2),
			role=RoleEnum.USER,
		)

		self.token = _access_token_for(self.user)

	def test_notification_consumer_receives_group_event(self):
		async def _run():
			from myproject.asgi import application as asgi_app

			communicator = WebsocketCommunicator(asgi_app, f"/ws/notifications/?token={self.token}")
			connected, _ = await communicator.connect()
			self.assertTrue(connected)

			#send to the user's notifications group
			channel_layer = get_channel_layer()
			await channel_layer.group_send(
				f"notifications_user_{self.user.id}",
				{"type": "notification_event", "notification": {"title": "Hello"}},
			)

			msg = await communicator.receive_json_from(timeout=2)
			self.assertEqual(msg.get("type"), "notification")
			self.assertEqual(msg["notification"]["title"], "Hello")

			await communicator.disconnect()

		async_to_sync(_run)()
from __future__ import annotations

import datetime

from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework import serializers
from rest_framework.exceptions import ValidationError
from rest_framework.test import APIRequestFactory

from accounts.models import RoleEnum, User
from core.models import Friend, FriendRequest, HashTag, Post, UserSession
from core.serializers import (
	FriendRequestCreateSerializer,
	FriendRequestResponseSerializer,
	HashTagRetrieveCreateUpdateSerializer,
)


class PostModelTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="postuser",
			email="post@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 1, 1),
			role=RoleEnum.USER,
		)

	def test_post_save_synchronizes_status_fields_and_scores(self):
		post = Post.objects.create(
			posted_by=self.user,
			caption="hi",
			status=Post.ModerationStatus.BLOCKED,
			moderation_status=Post.ModerationStatus.APPROVED,
			ai_score=0.33,
			moderation_score=None,
		)
		post.refresh_from_db()
		self.assertEqual(post.moderation_status, Post.ModerationStatus.BLOCKED)
		self.assertEqual(post.status, Post.ModerationStatus.BLOCKED)
		self.assertEqual(post.moderation_score, 0.33)

		post2 = Post.objects.create(
			posted_by=self.user,
			caption="hi2",
			status=Post.ModerationStatus.APPROVED,
			moderation_status=Post.ModerationStatus.PENDING_REVIEW,
			ai_score=None,
			moderation_score=0.7,
		)
		post2.refresh_from_db()
		#implementation always prefers `status` and overwrites `moderation_status` when both are set
		self.assertEqual(post2.status, Post.ModerationStatus.APPROVED)
		self.assertEqual(post2.moderation_status, Post.ModerationStatus.APPROVED)
		self.assertEqual(post2.ai_score, 0.7)

	def test_post_soft_delete_hides_from_default_manager(self):
		post = Post.objects.create(posted_by=self.user, caption="x")
		self.assertTrue(Post.objects.filter(pk=post.pk).exists())
		post.soft_delete()
		self.assertFalse(Post.objects.filter(pk=post.pk).exists())


class FriendRequestModelTests(TestCase):
	def setUp(self):
		self.user1 = User.objects.create_user(
			username="fr1",
			email="fr1@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 2, 2),
			role=RoleEnum.USER,
		)
		self.user2 = User.objects.create_user(
			username="fr2",
			email="fr2@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 2, 3),
			role=RoleEnum.USER,
		)

	def test_friend_request_rejects_self_request(self):
		fr = FriendRequest(from_user=self.user1, to_user=self.user1)
		with self.assertRaises(ValidationError):
			fr.save()

	def test_friend_request_str_contains_direction_and_status(self):
		fr = FriendRequest.objects.create(from_user=self.user1, to_user=self.user2)
		self.assertIn("→", str(fr))
		self.assertIn("pending", str(fr))


class FriendRequestSerializerTests(TestCase):
	def setUp(self):
		self.factory = APIRequestFactory()
		self.user1 = User.objects.create_user(
			username="sfr1",
			email="sfr1@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 3, 3),
			role=RoleEnum.USER,
		)
		self.user2 = User.objects.create_user(
			username="sfr2",
			email="sfr2@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 3, 4),
			role=RoleEnum.USER,
		)

	def test_create_serializer_creates_friend_request(self):
		request = self.factory.post("/api/friend_request/")
		request.user = self.user1

		serializer = FriendRequestCreateSerializer(
			data={"to_username": self.user2.username},
			context={"request": request},
		)
		self.assertTrue(serializer.is_valid(), serializer.errors)
		fr = serializer.save()
		self.assertEqual(fr.from_user, self.user1)
		self.assertEqual(fr.to_user, self.user2)

	def test_create_serializer_rejects_self_request(self):
		request = self.factory.post("/api/friend_request/")
		request.user = self.user1

		serializer = FriendRequestCreateSerializer(
			data={"to_username": self.user1.username},
			context={"request": request},
		)
		self.assertFalse(serializer.is_valid())
		self.assertIn("friend_request", serializer.errors)

	def test_create_serializer_rejects_duplicate_pending_request(self):
		FriendRequest.objects.create(from_user=self.user1, to_user=self.user2)

		request = self.factory.post("/api/friend_request/")
		request.user = self.user1

		serializer = FriendRequestCreateSerializer(
			data={"to_username": self.user2.username},
			context={"request": request},
		)
		self.assertFalse(serializer.is_valid())
		self.assertIn("friend_request", serializer.errors)

	def test_response_serializer_accept_creates_friendship(self):
		fr = FriendRequest.objects.create(from_user=self.user1, to_user=self.user2)

		request = self.factory.patch("/api/friend_request_response/")
		request.user = self.user2

		serializer = FriendRequestResponseSerializer(
			instance=fr,
			data={"status": FriendRequest.RequestStatusEnum.ACCEPTED},
			context={"request": request},
		)
		self.assertTrue(serializer.is_valid(), serializer.errors)
		updated = serializer.save()
		self.assertEqual(updated.status, FriendRequest.RequestStatusEnum.ACCEPTED)
		self.assertIsNotNone(updated.responded_at)

		user1, user2 = sorted([self.user1, self.user2], key=lambda u: u.id)
		self.assertTrue(Friend.objects.filter(user1=user1, user2=user2).exists())

	def test_sender_cannot_accept_their_own_request(self):
		fr = FriendRequest.objects.create(from_user=self.user1, to_user=self.user2)

		request = self.factory.patch("/api/friend_request_response/")
		request.user = self.user1

		serializer = FriendRequestResponseSerializer(
			instance=fr,
			data={"status": FriendRequest.RequestStatusEnum.ACCEPTED},
			context={"request": request},
		)
		self.assertFalse(serializer.is_valid())


class FriendModelTests(TestCase):
	def test_friend_save_orders_users_canonically(self):
		u1 = User.objects.create_user(
			username="f1",
			email="f1@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 4, 1),
			role=RoleEnum.USER,
		)
		u2 = User.objects.create_user(
			username="f2",
			email="f2@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 4, 2),
			role=RoleEnum.USER,
		)
		#intentionally reversed order
		friend = Friend.objects.create(user1=max(u1, u2, key=lambda u: u.id), user2=min(u1, u2, key=lambda u: u.id))
		friend.refresh_from_db()
		self.assertLess(friend.user1.id, friend.user2.id)


class UserSessionTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="sess",
			email="sess@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 5, 5),
			role=RoleEnum.USER,
		)

	def test_user_session_duration_seconds_computed(self):
		now = timezone.now()
		session = UserSession.objects.create(user=self.user)
		session.start_time = now - datetime.timedelta(seconds=100)
		session.end_time = now
		session.save()
		self.assertEqual(session.duration_seconds, 100)

		session.end_time = session.start_time - datetime.timedelta(seconds=1)
		session.save()
		self.assertEqual(session.duration_seconds, 0)


class DailyUsageStatusTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="limituser",
			email="limit@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 6, 6),
			role=RoleEnum.USER,
		)
		self.admin = User.objects.create_user(
			username="limitadmin",
			email="limitadmin@example.com",
			password="StrongPass123!",
			birth_date=datetime.date(2015, 6, 7),
			role=RoleEnum.ADMIN,
			is_admin=True,
			is_staff=True,
		)

	@override_settings(DAILY_USAGE_LIMIT_SECONDS=3600)
	def test_daily_usage_merges_overlapping_sessions(self):
		from core.views import _daily_usage_status

		reference_time = datetime.datetime(2026, 4, 19, 12, 0, 0, tzinfo=datetime.timezone.utc)

		s1 = UserSession.objects.create(user=self.user)
		s1.start_time = datetime.datetime(2026, 4, 19, 11, 0, 0, tzinfo=datetime.timezone.utc)
		s1.end_time = datetime.datetime(2026, 4, 19, 11, 10, 0, tzinfo=datetime.timezone.utc)
		s1.save()

		s2 = UserSession.objects.create(user=self.user)
		s2.start_time = datetime.datetime(2026, 4, 19, 11, 5, 0, tzinfo=datetime.timezone.utc)
		s2.end_time = datetime.datetime(2026, 4, 19, 11, 20, 0, tzinfo=datetime.timezone.utc)
		s2.save()

		result = _daily_usage_status(self.user, reference_time=reference_time)
		self.assertEqual(result["used_seconds"], 20 * 60)
		self.assertEqual(result["remaining_seconds"], 3600 - 1200)
		self.assertFalse(result["is_locked"])

	@override_settings(DAILY_USAGE_LIMIT_SECONDS=3600)
	def test_admins_are_not_locked_out(self):
		from core.views import _daily_usage_status

		reference_time = datetime.datetime(2026, 4, 19, 12, 0, 0, tzinfo=datetime.timezone.utc)
		UserSession.objects.create(user=self.admin)
		result = _daily_usage_status(self.admin, reference_time=reference_time)
		self.assertEqual(result["used_seconds"], 0)
		self.assertEqual(result["remaining_seconds"], 3600)
		self.assertFalse(result["is_locked"])


class HashTagSerializerTests(TestCase):
	def test_hashtag_validate_name_requires_hash_and_not_empty(self):
		s = HashTagRetrieveCreateUpdateSerializer()

		with self.assertRaises(serializers.ValidationError):
			s.validate_name("hello")

		with self.assertRaises(serializers.ValidationError):
			s.validate_name("# ")

	def test_hashtag_validate_name_strips_spaces(self):
		s = HashTagRetrieveCreateUpdateSerializer()
		self.assertEqual(s.validate_name("# hello world "), "#helloworld")
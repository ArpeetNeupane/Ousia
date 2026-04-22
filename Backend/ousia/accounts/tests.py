from __future__ import annotations

from datetime import date, timedelta
from io import BytesIO
from types import SimpleNamespace
from unittest.mock import patch

from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase
from django.utils import timezone

from rest_framework.test import APIRequestFactory

from accounts.interest_sync import interest_to_hashtag_name, normalize_interest_name
from accounts.models import (
	AreaOfInterest,
	PasswordResetOTP,
	Profile,
	RoleEnum,
	User,
	UserAreaOfInterest,
)
from accounts.serializers import (
	UserAreaOfInterestSerializer,
	UserLoginSerializer,
	UserPasswordUpdateSerializer,
	UserRegistrationSerializer,
)
from accounts.views import ForgotPasswordAPI, ResetPasswordAPI, VerifyOTPAPI
from accounts.utils import SuccessfulUpdateThrottle
from core.models import HashTag
from core.utils.nsfw_classifier import NSFWVerdict


def _make_test_image(
	*,
	filename: str = "test.jpg",
	size: tuple[int, int] = (16, 16),
	color: tuple[int, int, int] = (255, 0, 0),
	fmt: str = "JPEG",
	content_type: str = "image/jpeg",
) -> SimpleUploadedFile:
	#pillow is already a dependency of the project
	from PIL import Image

	buffer = BytesIO()
	Image.new("RGB", size, color).save(buffer, format=fmt)
	buffer.seek(0)
	return SimpleUploadedFile(filename, buffer.getvalue(), content_type=content_type)


class UserManagerTests(TestCase):
	def test_normalize_username_lowercases_and_strips(self):
		self.assertEqual(User.objects.normalize_username("  Alice  "), "alice")

	def test_normalize_username_rejects_spaces(self):
		with self.assertRaises(ValueError):
			User.objects.normalize_username("a b")

	def test_create_user_sets_admin_flags_for_admin_role(self):
		user = User.objects.create_user(
			username="adminuser",
			email="admin@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 1, 1),
			role=RoleEnum.ADMIN,
		)
		self.assertTrue(user.is_staff)
		self.assertTrue(user.is_admin)


class UserModelValidationTests(TestCase):
	def test_user_save_rejects_username_with_spaces(self):
		user = User(
			username="bad name",
			email="x@example.com",
			birth_date=date(2015, 1, 1),
			role=RoleEnum.USER,
		)
		user.set_password("StrongPass123!")
		with self.assertRaises(DjangoValidationError):
			user.save()


class ProfileSignalTests(TestCase):
	def test_profile_created_on_user_create(self):
		user = User.objects.create_user(
			username="bob",
			email="bob@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 2, 2),
			role=RoleEnum.USER,
		)
		profile = Profile.objects.get(user=user)
		self.assertEqual(profile.synced_username, user.username)
		self.assertEqual(profile.synced_email, user.email)
		self.assertEqual(profile.synced_birth_date, user.birth_date)

	def test_profile_updates_when_user_updates(self):
		user = User.objects.create_user(
			username="carol",
			email="carol@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 3, 3),
			role=RoleEnum.USER,
		)
		user.email = "carol2@example.com"
		user.save()

		profile = Profile.objects.get(user=user)
		self.assertEqual(profile.synced_email, "carol2@example.com")

	def test_user_updates_when_profile_updates_synced_fields(self):
		user = User.objects.create_user(
			username="dave",
			email="dave@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 4, 4),
			role=RoleEnum.USER,
		)
		profile = Profile.objects.get(user=user)
		profile.synced_username = "dave2"
		profile.save()

		user.refresh_from_db()
		self.assertEqual(user.username, "dave2")


class PasswordResetOTPTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="otpuser",
			email="otp@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 5, 5),
			role=RoleEnum.USER,
		)

	def test_generate_for_user_replaces_previous_unused(self):
		first = PasswordResetOTP.generate_for_user(self.user)
		second = PasswordResetOTP.generate_for_user(self.user)

		self.assertNotEqual(first.otp, second.otp)
		self.assertEqual(PasswordResetOTP.objects.filter(user=self.user, is_used=False).count(), 1)

	def test_is_valid_false_when_used_or_expired(self):
		otp_obj = PasswordResetOTP.generate_for_user(self.user)
		self.assertTrue(otp_obj.is_valid())

		otp_obj.is_used = True
		otp_obj.save(update_fields=["is_used"])
		self.assertFalse(otp_obj.is_valid())

		otp_obj.is_used = False
		otp_obj.created_at = timezone.now() - timedelta(minutes=11)
		otp_obj.save(update_fields=["is_used", "created_at"])
		self.assertFalse(otp_obj.is_valid())


class UserLoginSerializerTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="loginuser",
			email="login@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 6, 6),
			role=RoleEnum.USER,
		)

	def test_login_rejects_invalid_credentials(self):
		serializer = UserLoginSerializer(data={"username": "loginuser", "password": "wrong"})
		self.assertFalse(serializer.is_valid())
		self.assertIn("message", serializer.errors)

	def test_login_rejects_deleted_user(self):
		self.user.is_deleted = True
		self.user.save(update_fields=["is_deleted"])
		serializer = UserLoginSerializer(data={"username": "loginuser", "password": "StrongPass123!"})
		self.assertFalse(serializer.is_valid())
		self.assertIn("message", serializer.errors)

	def test_login_rejects_inactive_user(self):
		self.user.is_active = False
		self.user.save(update_fields=["is_active"])
		serializer = UserLoginSerializer(data={"username": "loginuser", "password": "StrongPass123!"})
		self.assertFalse(serializer.is_valid())
		self.assertIn("message", serializer.errors)


class UserPasswordUpdateSerializerTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="pwuser",
			email="pw@example.com",
			password="OldPass123!",
			birth_date=date(2015, 7, 7),
			role=RoleEnum.USER,
		)

	def test_rejects_wrong_current_password(self):
		serializer = UserPasswordUpdateSerializer(
			instance=self.user,
			data={
				"current_password": "WrongPass123!",
				"new_password": "NewPass123!",
				"confirm_new_password": "NewPass123!",
			},
			partial=True,
		)
		self.assertFalse(serializer.is_valid())
		self.assertIn("current_password", serializer.errors)


class SuccessfulUpdateThrottleTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="throttleuser",
			email="throttle@example.com",
			password="OldPass123!",
			birth_date=date(2015, 8, 8),
			role=RoleEnum.USER,
		)
		self.factory = APIRequestFactory()

	def test_blocks_second_success_within_window(self):
		request = self.factory.put(
			"/api/user/password/",
			{"current_password": "OldPass123!", "new_password": "NewPass123!", "confirm_new_password": "NewPass123!"},
			format="json",
		)
		request.user = self.user

		throttle = SuccessfulUpdateThrottle()
		self.assertTrue(throttle.allow_request(request, view=None))
		throttle.throttle_success()

		throttle2 = SuccessfulUpdateThrottle()
		self.assertFalse(throttle2.allow_request(request, view=None))

	def test_rejects_same_new_password(self):
		serializer = UserPasswordUpdateSerializer(
			instance=self.user,
			data={
				"current_password": "OldPass123!",
				"new_password": "OldPass123!",
				"confirm_new_password": "OldPass123!",
			},
			partial=True,
		)
		self.assertFalse(serializer.is_valid())
		self.assertIn("current_password", serializer.errors)

	def test_updates_password_on_success(self):
		serializer = UserPasswordUpdateSerializer(
			instance=self.user,
			data={
				"current_password": "OldPass123!",
				"new_password": "NewPass123!",
				"confirm_new_password": "NewPass123!",
			},
			partial=True,
		)
		self.assertTrue(serializer.is_valid(), serializer.errors)
		serializer.save()
		self.user.refresh_from_db()
		self.assertTrue(self.user.check_password("NewPass123!"))


class UserRegistrationSerializerTests(TestCase):
	def _base_payload(self) -> dict:
		today = date.today()
		birth_date = date(today.year - 10, today.month, min(today.day, 28))
		return {
			"username": "newkid",
			"email": "kid@example.com",
			"role": RoleEnum.USER,
			"birth_date": birth_date,
			"password": "StrongPass123!",
			"confirm_password": "StrongPass123!",
			"selfie_image": _make_test_image(filename="selfie.jpg"),
			"idcard_image": _make_test_image(filename="id.jpg"),
		}

	@patch("core.utils.nsfw_classifier.NSFWTextClassifier.classify")
	@patch("accounts.serializers.verify_student_identity")
	@patch("cloudinary.uploader.upload")
	def test_register_valid_payload_creates_user_and_uploads_images(
		self,
		mock_upload,
		mock_verify,
		mock_text_classify,
	):
		mock_text_classify.return_value = SimpleNamespace(verdict=NSFWVerdict.PASS)

		payload = self._base_payload()
		dob: date = payload["birth_date"]
		mock_verify.return_value = {
			"is_match": True,
			"extracted_text": f"identity card dob {dob.day:02d}/{dob.month:02d}/{dob.year} school",
			"idcard_cv": None,
		}
		mock_upload.side_effect = [
			{"public_id": "selfie_pid"},
			{"public_id": "id_pid"},
		]

		serializer = UserRegistrationSerializer(data=payload)
		self.assertTrue(serializer.is_valid(), serializer.errors)
		user = serializer.save()

		self.assertEqual(user.selfie_public_id, "selfie_pid")
		self.assertEqual(user.idcard_public_id, "id_pid")
		self.assertTrue(Profile.objects.filter(user=user).exists())

	@patch("core.utils.nsfw_classifier.NSFWTextClassifier.classify")
	def test_register_rejects_underage_or_overage(self, mock_text_classify):
		mock_text_classify.return_value = SimpleNamespace(verdict=NSFWVerdict.PASS)
		payload = self._base_payload()

		today = date.today()
		payload["birth_date"] = date(today.year - 6, today.month, min(today.day, 28))
		serializer = UserRegistrationSerializer(data=payload)
		self.assertFalse(serializer.is_valid())
		self.assertIn("birth_date", serializer.errors)

		payload = self._base_payload()
		payload["birth_date"] = date(today.year - 14, today.month, min(today.day, 28))
		serializer = UserRegistrationSerializer(data=payload)
		self.assertFalse(serializer.is_valid())
		self.assertIn("birth_date", serializer.errors)


class InterestSyncTests(TestCase):
	def setUp(self):
		self.user = User.objects.create_user(
			username="interestadmin",
			email="ia@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 8, 8),
			role=RoleEnum.ADMIN,
		)

	def test_normalize_interest_name(self):
		self.assertEqual(normalize_interest_name("  Foo Bar  "), "foobar")
		self.assertEqual(normalize_interest_name(""), "")

	def test_interest_to_hashtag_name(self):
		self.assertEqual(interest_to_hashtag_name("  Foo Bar  "), "#foobar")
		self.assertEqual(interest_to_hashtag_name(""), "")

	def test_area_of_interest_signal_creates_hashtag(self):
		interest = AreaOfInterest.objects.create(
			name="Drawing",
			description="Art interest",
			created_by=self.user,
		)
		self.assertTrue(HashTag.objects.filter(name="#drawing").exists())
		self.assertEqual(str(interest), "Drawing")


class UserAreaOfInterestSerializerTests(TestCase):
	def setUp(self):
		self.factory = APIRequestFactory()
		self.user = User.objects.create_user(
			username="uaiuser",
			email="uai@example.com",
			password="StrongPass123!",
			birth_date=date(2015, 9, 9),
			role=RoleEnum.USER,
		)
		self.interest = AreaOfInterest.objects.create(
			name="Chess",
			description="Strategy",
			created_by=self.user,
		)

	def test_rejects_duplicate_interest_selection(self):
		UserAreaOfInterest.objects.create(user=self.user, users_interest=self.interest)

		request = self.factory.post("/api/user-interests/")
		request.user = self.user

		serializer = UserAreaOfInterestSerializer(
			data={"users_interest": self.interest.id},
			context={"request": request},
		)
		self.assertFalse(serializer.is_valid())
		self.assertIn("users_interest", serializer.errors)


class ForgotPasswordDuplicateEmailFlowTests(TestCase):
	def setUp(self):
		self.factory = APIRequestFactory()
		self.email = "parent@example.com"
		self.user1 = User.objects.create_user(
			username="childone",
			email=self.email,
			password="OldPass123!",
			birth_date=date(2015, 10, 10),
			role=RoleEnum.USER,
		)
		self.user2 = User.objects.create_user(
			username="childtwo",
			email=self.email,
			password="OldPass123!",
			birth_date=date(2015, 10, 11),
			role=RoleEnum.USER,
		)

	@patch("accounts.models.User.send_email_to_user")
	def test_forgot_password_generates_shared_otp_for_all_users(self, mock_send_email):
		request = self.factory.post(
			"/forgot-password/",
			{"email": self.email},
			format="json",
		)
		response = ForgotPasswordAPI.as_view()(request)
		self.assertEqual(response.status_code, 200)
		mock_send_email.assert_called()

		otp1 = PasswordResetOTP.objects.filter(user=self.user1, is_used=False).latest("created_at")
		otp2 = PasswordResetOTP.objects.filter(user=self.user2, is_used=False).latest("created_at")
		self.assertEqual(otp1.otp, otp2.otp)

		verify_request = self.factory.post(
			"/verify-otp/",
			{"email": self.email, "otp": otp1.otp},
			format="json",
		)
		verify_response = VerifyOTPAPI.as_view()(verify_request)
		self.assertEqual(verify_response.status_code, 200)

		reset_missing_username = self.factory.post(
			"/reset-password/",
			{
				"email": self.email,
				"otp": otp1.otp,
				"new_password": "NewPass123!",
				"confirm_password": "NewPass123!",
			},
			format="json",
		)
		reset_missing_username_response = ResetPasswordAPI.as_view()(reset_missing_username)
		self.assertEqual(reset_missing_username_response.status_code, 400)

		reset_request = self.factory.post(
			"/reset-password/",
			{
				"email": self.email,
				"username": self.user2.username,
				"otp": otp1.otp,
				"new_password": "NewPass123!",
				"confirm_password": "NewPass123!",
			},
			format="json",
		)
		reset_response = ResetPasswordAPI.as_view()(reset_request)
		self.assertEqual(reset_response.status_code, 200)

		self.user2.refresh_from_db()
		self.assertTrue(self.user2.check_password("NewPass123!"))
		# Ensure OTP is consumed for the targeted user
		otp2.refresh_from_db()
		self.assertTrue(otp2.is_used)
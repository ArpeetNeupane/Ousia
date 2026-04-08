from django.db import models
from django.contrib.auth.models import BaseUserManager, AbstractBaseUser, PermissionsMixin
from django.conf import settings
from django.core.mail import send_mail, EmailMultiAlternatives
from django.utils import timezone
from django.utils.translation import gettext_lazy as _

import random
from datetime import timedelta


class RoleEnum(models.TextChoices):
    SUPERUSER = 'superuser', _('SUPERUSER')
    ADMIN = 'admin', _('ADMIN')
    USER = 'user', _('USER')


class UserManager(BaseUserManager):
    use_in_migrations = True #very crucial so that when creating future users, django doesn't forget to implement the rules set here like hashing passwords, etc.

    def create_user(self, username, email, password, birth_date, role, **extra_fields):
        if not username:
            raise ValueError("A username must be set.")
        if not email:
            raise ValueError("An email must be set.")
        if not role:
            raise ValueError("A role must be set.")
        if not birth_date:
            raise ValueError("Birth date must be set.")

        if role == RoleEnum.ADMIN:
            extra_fields.setdefault("is_admin", True)
            extra_fields.setdefault("is_staff", True)

        email = self.normalize_email(email) #normalize_email is a helper method on the manager itself so you dont need to call model
        username = self.model.normalize_username(username) #normalize_username is a custom method
        user = self.model(username=username, email=email, birth_date=birth_date, role=role, **extra_fields)
        user.set_password(password) #set_password hashes it by default
        user.save(using=self._db)
        return user

    def create_superuser(self, username, birth_date, email=None, password=None, role=RoleEnum.SUPERUSER.value, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_admin", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("A superuser must be a staff by default.")
        if extra_fields.get("is_admin") is not True:
            raise ValueError("A superuser must be an admin by default.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("A superuser must have is_superuser=True.")

        return self.create_user(username, email, password, birth_date, role, **extra_fields)

    @staticmethod
    def normalize_username(username):
        if not username:
            raise ValueError("Username cannot be empty or None.")
        return username.lower().strip()


class User(AbstractBaseUser, PermissionsMixin): #abstractbaseuser provides password, last_login, is_authenticated
    class Meta:
        verbose_name = 'User'
        verbose_name_plural = 'Users'
        ordering = ['-date_joined'] #newest first
    
    username = models.CharField(max_length=50, unique=True)
    email = models.EmailField(max_length=255, unique=False)
    role = models.CharField(
        max_length=20,
        choices=RoleEnum.choices,
        default=RoleEnum.USER.value
    )
    birth_date = models.DateField(max_length=15)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_admin = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)
    is_deleted = models.BooleanField(default=False)

    selfie_public_id = models.CharField(max_length=2056, blank=True, null=True, help_text=_("Public id of the selfie."))
    idcard_public_id = models.CharField(max_length=2056, blank=True, null=True, help_text=_("Public id of the id card."))

    has_completed_interests = models.BooleanField(default=False) #field to track if user has selected interests or not

    objects = UserManager() #connecting to the manager created above

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email', 'birth_date'] #fields required(aside from username and password)

    def __str__(self):
        return self.username

    # def clean(self):
    #     if not self.phone_number.isdigit():
    #         raise ValidationError({'phone_number': 'Phone number must only contain digits.'})
    #     if len(self.phone_number) < 10:
    #         raise ValidationError({'phone_number': 'Phone number must have at least 10 digits.'})

    def save(self, *args, **kwargs):
        #running full validation before saving to ensure clean() rules are applied
        self.full_clean()
        super().save(*args, **kwargs)

    def has_perm(self, perm, obj=None):
        if self.is_superuser:
            return True
        return False

    def has_module_perms(self, app_label):
        if self.is_superuser:
            return True
        return False

    def soft_delete(self):
        if not self.is_deleted:
            self.is_deleted = True
            self.save()

    def send_email_to_user(self, subject, message, sender_email=None, **kwargs):
        html_message = kwargs.pop('html_message', None)
        from_email = sender_email or settings.DEFAULT_FROM_EMAIL

        if html_message:
            email = EmailMultiAlternatives(
                subject=subject,
                body=message,
                from_email=from_email,
                to=[self.email],
                **kwargs,
            )
            email.attach_alternative(html_message, "text/html")
            email.send()
            return

        send_mail(subject, message, from_email, [self.email], **kwargs)


class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='user_profile')
    pfp_public_id = models.CharField(max_length=255, null=True, blank=True, help_text=_("Cloudinary public ID for the uploaded profile picture."))
    bio = models.CharField(max_length=500, blank=True, null=True)
    address = models.CharField(max_length=100, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    synced_username = models.CharField(max_length=50, blank=True)
    synced_email = models.EmailField(max_length=255, blank=True)
    synced_birth_date = models.DateField(blank=True, null=True)

    class Meta:
        verbose_name = 'Profile'
        verbose_name_plural = 'Profiles'

    def __str__(self):
        return f"{self.user.username}'s Profile"

class AreaOfInterest(models.Model):
    name = models.CharField(max_length=50)
    description = models.CharField(max_length=255, blank=True, null=True)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name='interest_creator')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['name'], name="unique_interest_name")
        ]
        ordering = ["created_at"]

    def __str__(self):
        return self.name

    def __repr__(self):
        return (f"AreaOfInterest(name={self.name!r},"
                f"created_by={self.created_by!r},"
                f"created_at={self.created_at.isoformat()})")


class UserAreaOfInterest(models.Model):
    users_interest = models.ForeignKey(AreaOfInterest, on_delete=models.CASCADE, related_name='users_interest')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='user_related_interest')

    class Meta:
        unique_together = ("user", "users_interest") #making sure an interest can't be selected twice
        verbose_name = "User Area of Interest"
        verbose_name_plural = "User Areas of Interest"

    def __str__(self):
        return f"{self.user.username} - {self.users_interest.name}"


class PasswordResetOTP(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    otp = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_used = models.BooleanField(default=False)

    def is_valid(self):
        #otp is only valid if it's not used and created within the last 10 minutes
        return not self.is_used and timezone.now() < self.created_at + timedelta(minutes=10)

    @classmethod
    def generate_for_user(cls, user):
        cls.objects.filter(user=user, is_used=False).delete()
        otp = str(random.randint(100000, 999999))
        return cls.objects.create(user=user, otp=otp)


class UserDeviceToken(models.Model):
    class Platform(models.TextChoices):
        ANDROID = 'android', 'Android'
        IOS = 'ios', 'iOS'
        WEB = 'web', 'Web'
        UNKNOWN = 'unknown', 'Unknown'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='device_tokens')
    token = models.CharField(max_length=512, unique=True)
    platform = models.CharField(max_length=20, choices=Platform.choices, default=Platform.UNKNOWN)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    last_seen_at = models.DateTimeField(auto_now=True)

    class Meta:
        indexes = [
            models.Index(fields=['user', 'is_active']),
        ]
        verbose_name = 'User Device Token'
        verbose_name_plural = 'User Device Tokens'

    def __str__(self):
        return f"{self.user.username} [{self.platform}]"
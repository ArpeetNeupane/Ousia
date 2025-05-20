from django.db import models
from django.contrib.auth.models import BaseUserManager, AbstractBaseUser
from django.core.mail import send_mail

from enum import Enum

class RoleEnum(Enum):
    SUPERUSER = 'superuser'
    ADMIN = 'admin'
    USER = 'user'

    @classmethod
    def choices(cls):
        return [(role.name, role.value) for role in cls] #same as writing for role in RoleEnum as cls refers to the class itself


class UserManager(BaseUserManager):
    use_in_migrations = True #very crucial so that when creating future users, django doesn't forget to implement the rules set here like hashing passwords, etc.

    def create_user(self, username, email, password, phone_number, role, **extra_fields):
        if not username:
            raise ValueError("A username must be set.")
        if not email:
            raise ValueError("An email must be set.")
        if not role:
            raise ValueError("A role must be set.")
        if not phone_number:
            raise ValueError("A phone number must be set.")

        email = self.normalize_email(email) #normalize_email is a helper method on the manager itself so you dont need to call model
        username = self.model.normalize_username(username) #normalize_username is a custom method
        user = self.model(username=username, email=email, phone_number=phone_number, role=role, **extra_fields)
        user.set_password(password) #set_password hashes it by default
        user.save(using=self._db)
        return user

    def create_superuser(self, username, phone_number, email=None, password=None, role=RoleEnum.SUPERUSER.value, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_admin", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("A superuser must be a staff by default.")
        if extra_fields.get("is_admin") is not True:
            raise ValueError("A superuser must be an admin by default.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("A superuser must have is_superuser=True.")

        return self.create_user(username, email, password, phone_number, role, **extra_fields)

    @staticmethod
    def normalize_username(username):
        return username.lower().strip() if username else ''


class User(AbstractBaseUser): #abstractbaseuser provides password, last_login, is_authenticated
    class Meta:
        verbose_name = 'User'
        verbose_name_plural = 'Users'
        ordering = ['-date_joined'] #newest first
    
    username = models.CharField(max_length=50, unique=True)
    email = models.EmailField(max_length=255, unique=True)
    role = models.CharField(
        max_length=20,
        choices=RoleEnum.choices(),
        default=RoleEnum.USER.value
    )
    phone_number = models.CharField(max_length=15)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_admin = models.BooleanField(default=False)
    is_superuser = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager() #connecting to the manager created above

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email', 'phone_number'] #fields required(aside from username and password) when creating superuser

    def __str__(self):
        return self.username

    def has_perm(self, perm, obj=None):
        if self.is_superuser:
            return True
        return False

    def has_module_perms(self, app_label):
        if self.is_superuser:
            return True
        return False

    def send_email_to_user(self, subject, message, sender_email=None, **kwargs):
        send_mail(self, subject, message, sender_email, [self.email], **kwargs)


class AreaOfInterest(models.Model):
    name = models.CharField(max_length=50)
    description = models.CharField(max_length=255, blank=True, null=True)
    created_by = models.ForeignKey(User, on_delete=models.PROTECT, related_name='interest_creator')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.name


class UserAreaOfInterest(models.Model):
    usersInterest = models.ForeignKey(AreaOfInterest, on_delete=models.CASCADE, related_name='users_interest')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='user_related_interest')

    class Meta:
        unique_together = ("user", "usersInterest") #making sure an interest can't be selected twice
        verbose_name = "User Area of Interest"
        verbose_name_plural = "User Areas of Interest"

    def __str__(self):
        return f"{self.user.username} - {self.usersInterest.name}"
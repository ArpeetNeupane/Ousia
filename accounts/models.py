from django.db import models
from django.contrib.auth.models import BaseUserManager, AbstractBaseUser, PermissionsMixin

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
            raise ValueError("A phone_number must be set.")

        email = self.normalize_email(email) #normalize_email is a helper method on the manager itself so you dont need to call model
        username = self.model.normalize_username(username) #normalize_username is a custom method
        user = self.model(username=username, email=email, phone_number=phone_number, role=role, **extra_fields)
        user.set_password(password) #set_password hashes it by default
        user.save(using=self._db)
        return user

    def create_superuser(self, username, phone_number, email=None, password=None, role=RoleEnum.SUPERUSER, **extra_fields):
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
        return username.lower() if username else ''

class User(AbstractBaseUser, PermissionsMixin): #abstractbaseuser provides password, last_login, is_authenticated
    username = models.CharField(max_length=50, unique=True, blank=False, null=False)
    email = models.EmailField(max_length=255, blank=False, null=False)
    role = models.CharField(
        max_length=20,
        choices=RoleEnum.choices(),
        blank=False,
        null=False,
        default=RoleEnum.USER
    )
    phone_number = models.CharField(max_length=15, blank=False, null=False)

    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    is_admin = models.BooleanField(default=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager() #connecting to the manager created above

    USERNAME_FIELD = 'username'
    REQUIRED_FIELDS = ['email'] #fields required(aside from username and password) when creating superuser
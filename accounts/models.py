from django.db import models
from django.contrib.auth.models import BaseUserManager

class UserManager(BaseUserManager):
    use_in_migrations = True #very crucial so that when creating future users, django doesn't forget to implement the rules set here like hashing passwords, etc.

    def create_user(self, username, email, password, **extra_fields):
        if not username:
            raise ValueError("A username must be set.")
        if not email:
            raise ValueError("An email must be set.")

        email = self.normalize_email(email) #normalize_email is a helper method on the manager itself so you dont need to call model
        username = self.model.normalize_username(username) #normalize_username is a custom method
        user = self.model(username=username, email=email, **extra_fields)
        user.set_password(password) #set_password hashes it by default
        user.save(using=self._db)
        return user

    def create_superuser(self, username, email=None, password=None, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_admin", True)
        extra_fields.setdefault("is_superuser", True)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("A superuser must be a staff by default.")
        if extra_fields.get("is_admin") is not True:
            raise ValueError("A superuser must be an admin by default.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("A superuser must have is_superuser=True.")

        return self.create_user(username, email, password, **extra_fields)

    @staticmethod
    def normalize_username(username):
        return username.lower() if username else ''
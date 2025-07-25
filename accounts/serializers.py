from django.core.exceptions import ValidationError
from django.core.files.images import get_image_dimensions
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth import authenticate
from django.db import transaction
from django.conf import settings

from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import User, Profile

from cloudinary.utils import cloudinary_url
from cloudinary.uploader import upload as cloudinary_upload

import os


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['username', 'email', 'role', 'phone_number']
        read_only_fields = ['date_joined']


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True)
    confirm_password = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'role', 'phone_number', 'password', 'confirm_password']

    def validate(self, data):
        password = data['password']
        confirm_password = data["confirm_password"]
        phone_number = data['phone_number']

        if not phone_number.isdigit():
            raise serializers.ValidationError(
                {"phone_number": "Phone number must only contain digits."}
            )
        if len(phone_number) < 10:
            raise serializers.ValidationError(
                {"phone_number": "Phone number must have at least 10 digits."}
            )

        try:
            validate_password(password)
        except ValidationError as e:
            raise serializers.ValidationError(
                {"password": e.messages}
            )

        if password != confirm_password:
            raise serializers.ValidationError(
                {"password": "Passwords do not match."}
            )
        return data

    def create(self, validated_data):
        password = validated_data.pop('password')
        validated_data.pop('confirm_password')

        user = User.objects.create_user(password=password, **validated_data)
        return user


class UserLoginSerializer(serializers.Serializer): #using Serializer here instead of ModelSerializer as we're not working with any CRUD operations that require model access, we're just validating the user credentials
    username = serializers.CharField(required=True)
    password = serializers.CharField(write_only = True, required=True)

    def validate(self, data):
        username = data['username']
        password = data['password']

        #authenticate() returns the user if credentials are correct
        user = authenticate(username=username, password=password)

        if user is None:
            raise serializers.ValidationError(
                {"message": "Invalid Credentials."}
            )
        if not user.is_active:
            raise serializers.ValidationError(
                {"message": "Please activate your account by contacting the admin before attempting login."}
            )

        self.user = user #storing for use in to_representation
        return data

    def to_representation(self, instance): #this method handles what to show in response after validation
        #UserSerializer doesn't include password in fields, so it never shows up in to_repr's data.
        user_data = UserSerializer(instance=self.user).data

        #generating refresh and access tokens
        refresh = RefreshToken.for_user(self.user)
        user_data['access_token'] = str(refresh.access_token)
        user_data['refresh_token'] = str(refresh)

        return user_data


class UserPasswordUpdateSerializer(serializers.Serializer):
    current_password = serializers.CharField(write_only=True, required=True)
    new_password = serializers.CharField(write_only=True, required=True)
    confirm_new_password = serializers.CharField(write_only=True, required=True)

    def validate_current_password(self, value):
        user = self.instance #current user, not request.user (that's in view, serializer shouldn't depend on view)
        #when view passes instance=request.user, in serializer: self.instance = self.request.user which gives current user
        if not user.check_password(value):
            raise serializers.ValidationError("Current password is incorrect.")
        return value

    def validate(self, data):
        current_password = data.get("current_password")
        new_password = data.get("new_password")
        confirm_new_password = data.get("confirm_new_password")

        if new_password == current_password:
            raise serializers.ValidationError({"current_password": "New password cannot be the same as current password."})

        if new_password != confirm_new_password:
            raise serializers.ValidationError({"new_password": "New passwords do not match."})

        try:
            validate_password(new_password, self.instance) #validate_password() to enforce password rules, passing instance for user-specific validators (like reusing old password prevention).
        except ValidationError as e:
            raise serializers.ValidationError(
                {"new_password": e.messages}
            )
        return data

    def update(self, instance, validated_data):
        instance.set_password(validated_data['new_password'])
        instance.save()
        return instance


class ProfileUpdateSerializer(serializers.ModelSerializer):
    pfp = serializers.ImageField(write_only=True, required=False)
    pfp_url = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = Profile
        fields = [
            'id', 'synced_username', 'synced_email', 'synced_phone_number', 'bio', 'address', 'birth_date',
            'created_at', 'updated_at', 'pfp_public_id', 'pfp_url', 'pfp'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'pfp_public_id', 'pfp_url']

    def get_pfp_url(self, obj):
        if not obj.pfp_public_id:
            return None
        url, _ = cloudinary_url(obj.pfp_public_id, resource_type="image")
        return url

    def validate_pfp(self, data):
        max_size_mb = getattr(settings, 'MAX_IMAGE_SIZE_MB', 6) * 1024 * 1024
        if data.size > max_size_mb:
            raise serializers.ValidationError(
                {"pfp": "Max size of profile picture should be less than 6 MB."}
            )

        #checking image dimensions
        width,height =  get_image_dimensions(data)
        max_width = getattr(settings, 'MAX_IMAGE_WIDTH', 2500)
        max_height = getattr(settings, 'MAX_IMAGE_HEIGHT', 1500)
        if width > max_width or height > max_height:
            raise serializers.ValidationError(
                {"pfp": "Profile picture dimension should not exceed 2500x1500px."}
            )

        #checking allowed extensions
        ext = os.path.splitext(data.name)[1].lower()
        allowed_exts = [".jpg", ".jpeg", ".png", ".webp"]
        if ext not in allowed_exts:
            raise serializers.ValidationError(
                {"pfp": f"Unsupported file extension '{ext}'. Allowed: {', '.join(allowed_exts)}"}
            )

        #checking MIME type. ImageField already checks but doubling down
        mime_type = data.content_type
        if not mime_type.startswith("image/"):
            raise serializers.ValidationError("Uploaded file is not an image.")

        return data

    def update(self, instance, validated_data):
        with transaction.atomic():
            for field in ['synced_username', 'synced_email', 'synced_phone_number', 'bio', 'address', 'birth_date']:
                value = validated_data.get(field, None)
                if value == "":
                    validated_data.pop(field)

            image = validated_data.pop('pfp', None)
            if image:
                result = cloudinary_upload(image)
                instance.pfp_public_id = result.get("public_id")

            return super().update(instance, validated_data)
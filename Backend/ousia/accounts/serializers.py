from django.core.exceptions import ValidationError
from django.core.files.images import get_image_dimensions
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth import authenticate
from django.db import transaction
from django.conf import settings

from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import User, Profile, RoleEnum

import cloudinary
from cloudinary.utils import cloudinary_url
from cloudinary.uploader import upload as cloudinary_upload

import os


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'birth_date']
        read_only_fields = ['id', 'date_joined']


class UserRegistrationSerializer(serializers.ModelSerializer):
    selfie_image = serializers.ImageField(write_only=True)
    selfie_url = serializers.SerializerMethodField(read_only=True)
    idcard_image = serializers.ImageField(write_only=True)
    idcard_url = serializers.SerializerMethodField(read_only=True)

    password = serializers.CharField(write_only=True, required=True)
    confirm_password = serializers.CharField(write_only=True, required=True)

    class Meta:
        model = User
        fields = ['id', 'username', 'email', 'role', 'birth_date', 'password', 'confirm_password',
                    'selfie_public_id', 'selfie_image', 'selfie_url',
                    'idcard_public_id', 'idcard_image', 'idcard_url'
        ]
        read_only_fields = ['id', 'selfie_public_id', 'idcard_public_id']

    def get_selfie_url(self, obj):
        try:
            public_id = getattr(obj, "selfie_public_id", None)
            #returning no url if public id isn't found
            if not public_id:
                return None

            url, _ = cloudinary_url(public_id, resource_type="image", secure=True)
            return url
        except Exception:
            return None

    def get_idcard_url(self, obj):
        try:
            public_id = getattr(obj, "idcard_public_id", None)
            #returning no url if public id isn't found
            if not public_id:
                return None

            url, _ = cloudinary_url(public_id, resource_type="image", secure=True)
            return url
        except Exception:
            return None

    def validate(self, data):
        username = data['username']
        password = data['password']
        confirm_password = data["confirm_password"]
        role = data['role']

        if len(username) < 3 and len(username) > 20:
            raise serializers.ValidationError(
                {"username": "Username must be between 3-20 letters long"}
            )

        existing_superuser = User.objects.filter(role=RoleEnum.SUPERUSER).exists()
        if role==RoleEnum.SUPERUSER and existing_superuser:
            raise serializers.ValidationError(
                {"existing_role": "A superuser already exists."}
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

        if role != RoleEnum.SUPERUSER:
            if "selfie_image" not in data:
                raise serializers.ValidationError({
                    "selfie_image": "Selfie image is required."
                })
            if "idcard_image" not in data:
                raise serializers.ValidationError({
                    "idcard_image": "ID card image is required."
                })

        return data

    def create(self, validated_data):
        password = validated_data.pop('password')
        validated_data.pop('confirm_password')

        selfie_image = validated_data.pop("selfie_image", None)
        idcard_image = validated_data.pop("idcard_image", None)
        if selfie_image and idcard_image:
            upload_result_selfie = cloudinary.uploader.upload(selfie_image, resource_type="image")
            upload_result_idcard = cloudinary.uploader.upload(idcard_image, resource_type="image")
            validated_data["selfie_public_id"] = upload_result_selfie.get("public_id")
            validated_data["idcard_public_id"] = upload_result_idcard.get("public_id")

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


class ProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model=Profile
        fields=['id', 'synced_username', 'synced_email', 'synced_birth_date', 'bio', 'address',
            'created_at', 'updated_at', 'pfp_public_id']


class ProfilePictureSerializer(serializers.ModelSerializer):
    pfp_url = serializers.SerializerMethodField(read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    class Meta:
        model=Profile
        fields = ['pfp_url', 'username']

    def get_pfp_url(self, obj):
        if not obj.pfp_public_id:
            return None
        url, _ = cloudinary_url(obj.pfp_public_id, resource_type="image")
        return url


class ProfileUpdateSerializer(serializers.ModelSerializer):
    pfp = serializers.ImageField(write_only=True, required=False)
    pfp_url = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = Profile
        fields = [
            'id', 'synced_username', 'synced_email', 'synced_birth_date', 'bio', 'address',
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
            for field in ['synced_username', 'synced_email', 'synced_birth_date', 'bio', 'address', 'birth_date']:
                value = validated_data.get(field, None)
                if value == "":
                    validated_data.pop(field)

            image = validated_data.pop('pfp', None)
            if image:
                result = cloudinary_upload(image)
                instance.pfp_public_id = result.get("public_id")

            return super().update(instance, validated_data)


class ProfileAdminUpdateSerializer(serializers.ModelSerializer):
    pfp = serializers.ImageField(write_only=True, required=False)
    pfp_url = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = Profile
        fields = [
            'id', 'synced_username', 'synced_email', 'synced_birth_date', 'bio', 'address', 'birth_date',
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
            for field in ['synced_username', 'synced_email', 'synced_birth_date', 'bio', 'address', 'birth_date']:
                value = validated_data.get(field, None)
                if value == "":
                    validated_data.pop(field)

            image = validated_data.pop('pfp', None)
            if image:
                result = cloudinary_upload(image)
                instance.pfp_public_id = result.get("public_id")

            return super().update(instance, validated_data)
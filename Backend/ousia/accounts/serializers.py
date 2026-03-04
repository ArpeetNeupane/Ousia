from django.core.exceptions import ValidationError
from django.core.files.images import get_image_dimensions
from django.contrib.auth.password_validation import validate_password
from django.contrib.auth import authenticate
from django.core.files.uploadedfile import InMemoryUploadedFile
from django.db import transaction
from django.conf import settings

from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import User, Profile, RoleEnum, AreaOfInterest, UserAreaOfInterest
from accounts.ai_utils import verify_student_identity, extract_dob_from_text, extract_text_from_id

import cloudinary
from cloudinary.utils import cloudinary_url
from cloudinary.uploader import upload as cloudinary_upload

import os, sys, nepali_datetime
from datetime import date
from PIL import Image
from io import BytesIO


#helper method for resizing image
def compress_and_resize_image(image_field, max_size=(800, 800)):
    """Resizing image to max_size and compressing it to save memory/upload time"""
    img = Image.open(image_field)
    if img.mode != 'RGB':
        img = img.convert('RGB')
    
    img.thumbnail(max_size, Image.Resampling.LANCZOS)
    
    output = BytesIO()
    img.save(output, format='JPEG', quality=85)
    output.seek(0)
    
    return InMemoryUploadedFile(
        output, 
        'ImageField', 
        f"{image_field.name.split('.')[0]}.jpg", 
        'image/jpeg', 
        sys.getsizeof(output), 
        None
    )


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

    def validate_birth_date(self, value):
        today_in_ad = date.today()
        today = nepali_datetime.date.from_datetime_date(today_in_ad)
        age = today.year - value.year - ((today.month, today.day) < (value.month, value.day))
        if age < 7 or age > 13:
            raise serializers.ValidationError("You must be between 7 and 13 years old to register.")
        return value

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

    #helper method to process AI results and return dictionary of errors
    def _check_ai_results(self, ai_results, validated_data):
        errors = {}
        e_text_id = ai_results.get('idcard_cv', '')

        if not ai_results.get('is_match'): 
            errors["identity"] = "The selfie does not match the photo on the ID card."
        
        text = extract_text_from_id(e_text_id)
        id_dob = extract_dob_from_text(text)

        if not id_dob:
            errors["id_card"] = "Date of birth not found on ID."

        else:
            entered_dob = validated_data.get("birth_date")

            #allowing ±1 year buffer due to possible OCR + calendar issues
            if abs((id_dob - entered_dob).days) > 365:
                errors["birth_date"] = (
                    f"Entered DOB does not match ID. "
                    f"ID shows {id_dob}."
                )

        #checking OCR keywords
        e_text = ai_results.get('extracted_text', '').lower()
        keywords = ['identity', 'card', 'dob', 'school', 'academy', 'grade', 'class', 'student', 'vidyalaya', 'college', 'campus', 'institute', 'pathshala', 'shikshya', '+2']
        if not any(k in e_text for k in keywords):
            errors["id_card"] = "Could not detect a valid school ID. Ensure the text is readable."

        return errors

    def validate(self, data):
        username = data.get('username')
        password = data.get('password')
        confirm_password = data.get("confirm_password")
        role = data.get('role')

        if len(username) < 3 or len(username) > 20:
            raise serializers.ValidationError(
                {"username": "Username must be between 3-20 letters long"}
            )

        existing_superuser = User.objects.filter(role=RoleEnum.SUPERUSER).exists()
        if role == RoleEnum.SUPERUSER and existing_superuser:
            raise serializers.ValidationError(
                {"existing_role": "A superuser already exists."}
            )
            
        try:
            validate_password(password)
        except Exception as e:
            raise serializers.ValidationError({"password": list(e) if hasattr(e, 'messages') else str(e)})

        if password != confirm_password:
            raise serializers.ValidationError({"password": "Passwords do not match."})

        #performing AI validation
        if role != RoleEnum.SUPERUSER:
            selfie_image = data.get("selfie_image")
            idcard_image = data.get("idcard_image")

            if not selfie_image:
                raise serializers.ValidationError({"selfie_image": "Selfie image is required."})
            if not idcard_image:
                raise serializers.ValidationError({"idcard_image": "ID card image is required."})
            
            #reading bytes for AI processing
            selfie_bytes = selfie_image.read()
            idcard_bytes = idcard_image.read()

            #resetting pointers so create() can read them again for upload
            selfie_image.seek(0)
            idcard_image.seek(0)

            #calling the utility function
            ai_results = verify_student_identity(selfie_bytes, idcard_bytes)
            ai_errors = self._check_ai_results(ai_results, data)
            
            if ai_errors:
                raise serializers.ValidationError(ai_errors)

        return data

    def create(self, validated_data):
        password = validated_data.pop('password')
        validated_data.pop('confirm_password', None)
        
        selfie_image = validated_data.pop("selfie_image", None)
        idcard_image = validated_data.pop("idcard_image", None)
        role = validated_data.get('role', RoleEnum.USER.value)

        #uploading to cloudinary only after AI validation has already passed
        if role != RoleEnum.SUPERUSER.value and selfie_image and idcard_image:
            #compressing images before upload
            compressed_selfie = compress_and_resize_image(selfie_image)
            compressed_idcard = compress_and_resize_image(idcard_image)

            upload_result_selfie = cloudinary.uploader.upload(compressed_selfie, resource_type="image")
            upload_result_idcard = cloudinary.uploader.upload(compressed_idcard, resource_type="image")
            
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


class AreaOfInterestSerializer(serializers.ModelSerializer):
    created_by_name = serializers.CharField(
        source="created_by.username", read_only=True
    )
    class Meta:
        model = AreaOfInterest
        fields = ["id", "name", "description", "created_by", "created_by_name", "created_at", "updated_at"]
        read_only_fields = ["id", "created_by", "created_at", "created_by_name", "updated_at"]

    def validate_name(self, value):
        value = value.strip()
        if len(value) > 50:
            raise serializers.ValidationError("Interest name cannot be longer than 50 characters.")
        return value

    def validate_description(self, value):
        value = value.strip()
        if not value:
            raise serializers.ValidationError("Description of interest cannot be empty.")
        if len(value) > 255:
            raise serializers.ValidationError("Description of interest cannot be longer than 255 characters.")
        return value


class UserAreaOfInterestSerializer(serializers.ModelSerializer):
    #nested display for easier frontend use, alternative to SerializerMethodField
    users_interest_name = serializers.CharField(
        source="users_interest.name", read_only=True
    )

    #handling pk related error message properly in POST
    users_interest = serializers.PrimaryKeyRelatedField(
        queryset=AreaOfInterest.objects.all(),
        error_messages={"does_not_exist": "Selected interest does not exist."}
    )
    
    class Meta:
        model = UserAreaOfInterest
        fields = ["id", "user", "users_interest", "users_interest_name"]
        read_only_fields = ["id", "user", "users_interest_name"]

    def validate(self, data):
        user = self.context["request"].user
        interest = data.get("users_interest")

        if UserAreaOfInterest.objects.filter(user=user, users_interest=interest).exists():
            raise serializers.ValidationError(
                {"users_interest": "You have already selected this interest."}
            )
        return data
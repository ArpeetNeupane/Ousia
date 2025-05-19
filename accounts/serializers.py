from django.core.exceptions import ValidationError
from django.contrib.auth.password_validation import validate_password

from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User

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
        if len(phone_number) != 10:
            raise serializers.ValidationError(
                {"phone_number": "Phone number must have exactly 10 digits."}
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

class UserLoginSerializer(serializers.Serializer): #using Serializer here instead of ModelSerializer as we're not working with any CRUD operations thta require model access, we're just validating the user credentials
    email = serializers.CharField(required = True)
    password = serializers.CharField(write_only = True, required=True)

    def validate(self, data):
        email = data['email']
        password = data['password']

        email_exists = User.objects.filter(email=email).exists()

        if not email_exists:
            raise serializers.ValidationError(
                {"message": "Invalid Credentials."}
            )
        user = User.objects.get(email=email)
        if not user.check_password(password):
            raise serializers.ValidationError(
                {"message": "Invalid Credentials."}
            )

        self.user = user #saving current validated user in this instance so that it can be used in to_representation later without lookup
        return data

    def to_representation(self, instance): #this method handles what to show in response after validation
        #UserSerializer doesn't include password in fields, so it never shows up in to_repr's data.
        user_data = UserSerializer(instance=self.user).data

        #generating refresh and access tokens
        refresh = RefreshToken.for_user(self.user)
        user_data['access_token'] = str(refresh.access_token)
        user_data['refresh_token'] = str(refresh)

        return user_data
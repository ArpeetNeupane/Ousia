from core.models import *

from rest_framework import serializers

class HashTagCreateUpdateSerializer(serializers.ModelSerializer):
    created_by_username = serializers.SerializerMethodField(read_only=True)
    class Meta:
        model = HashTag
        fields = ['id', 'name', 'created_by', 'created_by_username', 'created_at']
        read_only_fields = ['id', 'created_by', 'created_by_username', 'created_at']

    def get_created_by_username(self, obj):
        return obj.created_by.username if obj.created_by else None

    def validate_name(self, value): #when using validate_fieldname, the method gets raw field value by itself. data.get isnt required.
        #removing spaces
        value_no_spaces = value.replace(" ", "")
        value = value_no_spaces.strip()

        if not value.startswith('#'):
            raise serializers.ValidationError(
                {"hashtag": "A hashtag must start with a #."}
            )

        #making sure something remains after #, when user inputs something like "# "
        if len(value_no_spaces) == 1:
            raise serializers.ValidationError("Hashtag cannot be just #.")

        return value

    def create(self, validated_data):
        validated_data['created_by'] = self.context['request'].user
        return super().create(validated_data)

    def update(self, instance, validated_data):
        for attrs, value in validated_data.items():
            setattr(instance, attrs, value)
        instance.save()
        return instance
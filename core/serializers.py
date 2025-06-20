from core.models import *

from rest_framework import serializers

import cloudinary, cloudinary.uploader
from cloudinary.utils import cloudinary_url

class HashTagRetrieveCreateUpdateSerializer(serializers.ModelSerializer):
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


class PostRetrieveCreateSerializer(serializers.ModelSerializer):
    media = serializers.FileField(write_only=True, required=False)
    media_url = serializers.SerializerMethodField(read_only=True)

    type_of_post = serializers.SlugRelatedField(
        queryset=HashTag.objects.all(),
        slug_field='name',
        many=True
    )
    class Meta:
        model = Post
        fields = [
            'id', 'caption', 'visibility', 'created_at', 'posted_by',
            'type_of_post', 'media', 'media_url', 'post_like_count', 'post_comment_count'
        ]
        read_only_fields = ['id', 'created_at', 'posted_by', 'post_like_count', 'post_comment_count', 'media_url']

    def get_media_url(self, obj):
        #returning no url if public id isn't found
        if not obj.media_public_id:
            return None

        url, _ = cloudinary_url(
            obj.media_public_id,
            resource_type="video" if obj.is_video else "image",
            secure=True,
            fetch_format="auto",
            quality="auto"
        )
        return url

    def to_internal_value(self, data):
        if 'type_of_post' in data:
            hashtags = data.get('type_of_post')
            if isinstance(hashtags, str):
                #splitting comma-separated string into list
                hashtag_list = [tag.strip() for tag in hashtags.split(',') if tag.strip()]
                data = data.copy()
                data.setlist('type_of_post', hashtag_list)
        
        return super().to_internal_value(data)

    def create(self, validated_data):
        request = self.context['request']

        media_files = validated_data.pop('media', None)
        hashtags_data = validated_data.pop('type_of_post', [])

        try:
            #first, creating a post object and then linking the many-to-many hashtag field to it
            validated_data['posted_by'] = request.user
            post = super().create(validated_data)

            if hashtags_data:
                final_hashtags = []

                for name in hashtags_data:
                    try:
                        hashtag = HashTag.objects.get(name=name)
                        final_hashtags.append(hashtag)
                    except HashTag.DoesNotExist:
                        raise serializers.ValidationError(
                            {"hashtag:" "Hashtag with that name doesn't exist."}
                        )

                if final_hashtags:
                    post.type_of_post.set(final_hashtags)

            if media_files:
                uploaded = cloudinary.uploader.upload(media_files, resource_type='auto')
                post.media_public_id = uploaded['public_id']
                post.is_video = uploaded['resource_type'] == 'video'
                post.save(update_fields=['media_public_id', 'is_video'])

            return post

        except Exception:
            raise serializers.ValidationError("An error occured during creation of Post. Try again later.")



class PostUpdateSerializer(serializers.ModelSerializer):
    pass

class LikeRetrieveCreateSerializer(serializers.ModelSerializer):
    pass

class CommentRetrieveCreateSerializer(serializers.ModelSerializer):
    pass

class CommentUpdateSerializer(serializers.ModelSerializer):
    pass
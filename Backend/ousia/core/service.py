from django.db import transaction
from rest_framework import serializers
import cloudinary.uploader
from core.models import HashTag, MediaUpload, Post

class PostCreateService:
    @staticmethod
    def create_post_with_media_and_hashtags(user, validated_data, media_files, hashtags_string):
        uploaded_media = []

        #processing hashtags
        if hashtags_string:
            hashtag_names = [tag.strip() for tag in hashtags_string.split(',') if tag.strip()]
            final_hashtags = []

            for name in hashtag_names:
                try:
                    hashtag = HashTag.objects.get(name=name)
                    final_hashtags.append(hashtag)
                except HashTag.DoesNotExist:
                    raise serializers.ValidationError(
                        {"type_of_post": f"Hashtag '{name}' doesn't exist."}
                    )

        try:
            if media_files:
                #uploading media first outside of db transaction so that if transaction rolls back after media upload is successful, there aren't any orphaned/unlinked media
                for media_file in media_files:
                    uploaded = cloudinary.uploader.upload(media_file, resource_type='auto')
                    uploaded_media.append(uploaded)

            with transaction.atomic():
                #first, creating a post object and then linking the many-to-many hashtag field to it
                validated_data['posted_by'] = user
                post = Post.objects.create(**validated_data)

                if hashtags_string:
                    post.type_of_post.set(final_hashtags)

                #linking media uploads
                if media_files:
                    for index, media_file in enumerate(media_files):
                        uploaded = uploaded_media[index]
                        MediaUpload.objects.create(
                            post=post,
                            public_id=uploaded['public_id'],
                            is_video=uploaded['resource_type'] == 'video',
                            upload_order=index
                        )

                post.refresh_from_db()
                return post

        except serializers.ValidationError:
            #if validation error occurs, clean up uploaded media and re-raise exact error so that above hashtag validation error doesn't drown and a generic exception is shown
            for uploaded in uploaded_media:
                try:
                    cloudinary.uploader.destroy(
                        uploaded['public_id'],
                        resource_type=uploaded['resource_type']
                    )
                except Exception:
                    print("Failed to delete orphaned files.")
            raise #re-raising the validation error as-is

        except Exception as e:
            #on failure, cleaning up uploaded media to avoid orphan files
            for uploaded in uploaded_media:
                try:
                    cloudinary.uploader.destroy(
                        uploaded['public_id'],
                        resource_type=uploaded['resource_type']
                    )
                except Exception:
                    print("Failed to delete orphaned files.")

            print(str(e))
            raise serializers.ValidationError("An error occurred during creation of Post. Try again later.")



class PostUpdateService:
    @staticmethod
    def update_post_with_media_and_hashtags(instance, validated_data, media_files=None, hashtags_string=None):
        uploaded_media = []

        #updating hashtags
        if hashtags_string is not None:
            hashtag_names = {tag.strip() for tag in hashtags_string.split(',') if tag.strip()}  # set directly
            found_names = set(HashTag.objects.filter(name__in=hashtag_names).values_list('name', flat=True))

            missing = hashtag_names - found_names
            if missing:
                raise serializers.ValidationError(
                    {"type_of_post": f"Hashtag {', '.join(missing)} does not exist."}
                )

            hashtags = HashTag.objects.filter(name__in=found_names)  # fetch actual objects only if all are valid

        try:
            #uploading new media files if provided by user
            if media_files:
                for media_file in media_files:
                    uploaded = cloudinary.uploader.upload(media_file, resource_type='auto')
                    uploaded_media.append(uploaded)

            with transaction.atomic():
                #updating caption and visibility
                instance.caption = validated_data.get('caption', instance.caption)
                instance.visibility = validated_data.get('visibility', instance.visibility)
                instance.save()

                #processing hashtag update
                if hashtags_string is not None:
                    instance.type_of_post.set(hashtags)

                #replacing media
                if uploaded_media:
                    #deleting old Cloudinary files and DB records
                    for old_media in instance.post_media.all():
                        if old_media.public_id:
                            try:
                                cloudinary.uploader.destroy(
                                    old_media.public_id,
                                    resource_type='video' if old_media.is_video else 'image'
                                )
                            except Exception as e:
                                print(f"Cloudinary deletion failed for {old_media.public_id}: {e}")
                        old_media.delete()

                    for index, uploaded in enumerate(uploaded_media):
                        MediaUpload.objects.create(
                            post=instance,
                            public_id=uploaded['public_id'],
                            is_video=uploaded['resource_type'] == 'video',
                            upload_order=index
                        )

                instance.refresh_from_db()
                return instance

        except serializers.ValidationError:
            #if upload or DB update fails, cleanup uploaded media to avoid orphan files
            for uploaded in uploaded_media:
                try:
                    cloudinary.uploader.destroy(
                        uploaded['public_id'],
                        resource_type=uploaded['resource_type']
                    )
                except Exception:
                    print("Failed to delete orphaned files.")
            raise

        except Exception as e:
            for uploaded in uploaded_media:
                try:
                    cloudinary.uploader.destroy(
                        uploaded['public_id'],
                        resource_type=uploaded['resource_type']
                    )
                except Exception:
                    print("Failed to delete orphaned files.")

            print(str(e))
            raise serializers.ValidationError("An error occurred during update of Post. Try again later.")
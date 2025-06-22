import os, magic

from rest_framework import serializers

from django.conf import settings

class MediaValidationMixin:
    def validate_media(self, media_files):
        max_total = getattr(settings, 'MAX_MEDIA_TOTAL_FILES', 5) #5 is the default value if 'MAX_MEDIA_TOTAL_FILES' is not mentioned in settings
        max_videos = getattr(settings, 'MAX_MEDIA_VIDEOS', 2)
        max_images = getattr(settings, 'MAX_MEDIA_IMAGES', 3)
        max_image_size = getattr(settings, 'MAX_IMAGE_SIZE_MB', 6) * 1024 * 1024
        max_video_size = getattr(settings, 'MAX_VIDEO_SIZE_MB', 100) * 1024 * 1024

        allowed_image_exts = getattr(
            settings, 'ALLOWED_IMAGE_EXTENSIONS',
            {'.jpg', '.jpeg', '.png', '.webp', '.gif'} #default fallback
        )

        allowed_video_exts = getattr(
            settings, 'ALLOWED_VIDEO_EXTENSIONS',
            {'.mp4', '.mkv'}
        )

        image_count = 0
        video_count = 0

        if len(media_files) > max_total:
            raise serializers.ValidationError(f"Maximum of {max_total} media files allowed.")

        for f in media_files:
            name = f.name.lower()
            ext = os.path.splitext(name)[1]

            #reading a small portion of the file to know file content to detect MIME type
            mime = magic.Magic(mime=True)
            file_mime_type = mime.from_buffer(f.read(2048)) #reading first 2048 bytes
            f.seek(0) #resetting file pointer to 0 after reading

            if not file_mime_type:
                raise serializers.ValidationError(f"Could not determine file type for '{f.name}'.")

            #validating image
            if file_mime_type.startswith('image/') and ext in allowed_image_exts:
                image_count += 1
                if f.size > max_image_size:
                    raise serializers.ValidationError(f"Image '{f.name}' exceeds 6MB limit.")

            #validating video
            elif file_mime_type.startswith('video/') and ext in allowed_video_exts:
                video_count += 1
                if f.size > max_video_size:
                    raise serializers.ValidationError(f"Video '{f.name}' exceeds 100MB limit.")

            else:
                if file_mime_type.startswith('image/'):
                    raise serializers.ValidationError(
                        f"Unsupported file type '{f.name}'. Allowed types: "
                        f"{', '.join(sorted(allowed_image_exts | allowed_video_exts))}"
                    )
                else:
                    raise serializers.ValidationError(
                        {"mime_type": f"{file_mime_type} mime type is not allowed. Upload images or videos only."}
                    )

        if image_count > max_images:
            raise serializers.ValidationError(f"At most {max_images} images are allowed.")
        if video_count > max_videos:
            raise serializers.ValidationError(f"At most {max_videos} videos are allowed.")

        return media_files
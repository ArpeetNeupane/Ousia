import mimetypes
import os
from rest_framework import serializers

class MediaValidationMixin:
    def validate_media(self, media_files):
        max_total = 5
        max_videos = 2
        max_images = 3
        max_image_size = 6 * 1024 * 1024
        max_video_size = 100 * 1024 * 1024

        allowed_image_exts = {'.jpg', '.jpeg', '.png', '.webp'}
        allowed_video_exts = {'.mp4', '.mkv'}

        image_count = 0
        video_count = 0

        if len(media_files) > max_total:
            raise serializers.ValidationError(f"Maximum of {max_total} media files allowed.")

        for f in media_files:
            name = f.name.lower()
            ext = os.path.splitext(name)[1]

            mime_type, _ = mimetypes.guess_type(name)
            if not mime_type:
                raise serializers.ValidationError(f"Could not determine file type for '{f.name}'.")

            #validating image
            if mime_type.startswith('image/') and ext in allowed_image_exts:
                image_count += 1
                if f.size > max_image_size:
                    raise serializers.ValidationError(f"Image '{f.name}' exceeds 6MB limit.")

            #validating video
            elif mime_type.startswith('video/') and ext in allowed_video_exts:
                video_count += 1
                if f.size > max_video_size:
                    raise serializers.ValidationError(f"Video '{f.name}' exceeds 100MB limit.")

            else:
                raise serializers.ValidationError(
                    f"Unsupported file type '{f.name}'. Allowed types: "
                    f"{', '.join(sorted(allowed_image_exts | allowed_video_exts))}"
                )

        if image_count > max_images:
            raise serializers.ValidationError(f"At most {max_images} images are allowed.")
        if video_count > max_videos:
            raise serializers.ValidationError(f"At most {max_videos} videos are allowed.")

        return media_files
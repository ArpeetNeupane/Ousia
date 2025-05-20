from django.db import models
from accounts.models import User

class CurrentEmotion(models.Model):
    emotion_emoji_name = models.CharField(max_length=20)
    emotion_emoji_path = models.CharField(max_length=255, null=True, blank=True, help_text="The path to emotion in object storage.")
    current_emoji_url = models.CharField(max_length=2046, null=True, blank=True, help_text="Current presigned url for the emoji.")
    emoji_url_expiry_time = models.DateTimeField(null=True, blank=True, help_text="Expiration time of the current url.")

    def __str__(self):
        return self.emotion_emoji_name


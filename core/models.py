from django.db import models
from accounts.models import User
from django.utils.translation import gettext_lazy as _

class CurrentEmotion(models.Model):
    emotion_emoji_name = models.CharField(max_length=20)
    emotion_emoji_path = models.CharField(max_length=255, null=True, blank=True, help_text="The path to emotion emoji in object storage.")
    current_emoji_url = models.URLField(max_length=2046, null=True, blank=True, help_text="Current presigned url for the emoji.")
    emoji_url_expiry_time = models.DateTimeField(null=True, blank=True, help_text="Expiration time of the current url.")

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.emotion_emoji_name


class HashTag(models.Model):
    name = models.CharField(max_length=50, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='hashtag_creator')

    def __str__(self):
        return f"#{self.name}"


class Post(models.Model):
    class VisibilityEnum(models.TextChoices):
        PUBLIC = 'public', _('Public')
        PRIVATE = 'private', _('Private')
        FRIENDS_ONLY = 'friends_only', _('Friends Only')

    caption = models.CharField(max_length=200)
    post_image_path = models.CharField(max_length=255, null=True, blank=True, help_text="The path to post image in object storage.")
    current_post_image_url = models.URLField(max_length=2048, null=True, blank=True, help_text="Current presigned url for the post image.")
    post_image_url_expiry_time = models.DateTimeField(null=True, blank=True, help_text="Expiration time of the current url.")
    # posted_from = models.CharField(max_length=255, blank=True, null=True)
    visibility = models.CharField(
        max_length=20,
        choices=VisibilityEnum.choices,
        default=VisibilityEnum.FRIENDS_ONLY.value,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    posted_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='users_post')
    type_of_post = models.ManyToManyField(HashTag, related_name='tagged_posts', through='PostHashTag') #using '' to say thats its defined below this model or else itll throw an error

    class Meta:
        indexes = [
            models.Index(fields=['created_at']),
        ]

    def __str__(self):
        return f"{self.posted_by.username} - #{self.id}"


class PostHashTag(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE)
    hashtag = models.ForeignKey(HashTag, on_delete=models.CASCADE)

    class Meta:
        unique_together = ('post', 'hashtag')
        indexes = [
            models.Index(fields=['hashtag']),
            models.Index(fields=['post']),
        ]

    def __str__(self):
        return f"Post#{self.post.id} - {self.hashtag.name}"


class Like(models.Model):
    liked_by = models.ForeignKey(User, on_delete=models.CASCADE)
    liked_at = models.DateTimeField(auto_now_add=True)
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='like_on_post')

    class Meta:
        unique_together = ['liked_by', 'post']

        #creating database indexes to inprove query performance such as: PostLike.objects.filter(post=some_post)
        indexes = [
            models.Index(fields=['post']),
            models.Index(fields=['liked_by']),
        ]

    def __str__(self):
        return f"{self.liked_by.username} liked post {self.post}"

class Comment(models.Model):
    commented_by = models.ForeignKey(User, on_delete=models.CASCADE)
    content = models.CharField(max_length=1000, help_text="The actual comment on a post.")
    commented_at = models.DateTimeField(auto_now_add=True)
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comment_on_post')
    like_count = models.PositiveIntegerField(default=0, help_text="Number of likes on this comment.")

    class Meta:
        indexes = [
            models.Index(fields=['post', 'commented_at']),
            models.Index(fields=['post', 'like_count']),
            models.Index(fields=['post', 'like_count', 'id']),
        ]

    def __str__(self):
        return f"{self.commented_by.username} commented on post {self.post.id}"


class CommentLike(models.Model):
    liked_at = models.DateTimeField(auto_now_add=True)
    liked_by = models.ForeignKey(User, on_delete=models.CASCADE)
    comment = models.ForeignKey(Comment, on_delete=models.CASCADE, related_name='comment_liked')

    class Meta:
        unique_together = ('liked_by', 'comment')
        indexes = [
            models.Index(fields=['comment']),
            models.Index(fields=['liked_by']),
        ]

    def __str__(self):
        return f"{self.liked_by.username} liked comment #{self.comment.id} on post {self.comment.post.id}"
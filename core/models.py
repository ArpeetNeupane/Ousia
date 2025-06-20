from django.db import models
from django.utils.translation import gettext_lazy as _

from accounts.models import User
from core.managers import PostManager


class CurrentEmotion(models.Model):
    emotion_emoji_name = models.CharField(max_length=20)
    emotion_emoji_path = models.CharField(max_length=255, null=True, blank=True, help_text=_("The path to emotion emoji in object storage."))
    current_emoji_url = models.URLField(max_length=2048, null=True, blank=True, help_text=_("Current presigned url for the emoji."))
    emoji_url_expiry_time = models.DateTimeField(null=True, blank=True, help_text=_("Expiration time of the current url."))

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "CurrentEmotion"
        verbose_name_plural = "CurrentEmotions"

    def __str__(self):
        return self.emotion_emoji_name


class HashTag(models.Model):
    name = models.CharField(max_length=50, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='hashtag_creator')

    class Meta:
        verbose_name = "Hashtag"
        verbose_name_plural = "Hashtags"

    def __str__(self):
        return f"{self.name}"


class Post(models.Model):
    class VisibilityEnum(models.TextChoices):
        PUBLIC = 'public', _('Public')
        PRIVATE = 'private', _('Private')
        FRIENDS_ONLY = 'friends_only', _('Friends Only')

    caption = models.CharField(max_length=512, help_text=_("Text caption describing the post."))
    # posted_from = models.CharField(max_length=255, blank=True, null=True)
    visibility = models.CharField(
        max_length=20,
        choices=VisibilityEnum.choices,
        default=VisibilityEnum.FRIENDS_ONLY.value,
        help_text=_("Visibility level of the post (Public, Private, or Friends Only).")
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False, help_text=_("Flag to indicate if the post is soft deleted."))

    posted_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='users_post')
    type_of_post = models.ManyToManyField(HashTag, related_name='tagged_posts', through='PostHashTag') #using '' to say thats its defined below this model or else itll throw an error

    class Meta:
        verbose_name = "Post"
        verbose_name_plural = "Posts"
        indexes = [
            models.Index(fields=['created_at']),
        ]
        ordering = ['-created_at']

    objects = PostManager()

    def soft_delete(self):
        self.is_deleted = True
        self.save()

    @property
    def post_like_count(self):
        return self.like_on_post.count()

    @property
    def post_comment_count(self):
        return self.comment_on_post.count()

    def __str__(self):
        return f"{self.posted_by.username} - #{self.id}"


class MediaUpload(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='post_media')
    public_id = models.CharField(max_length=255, null=True, blank=True, help_text=_("Cloudinary public ID for the uploaded image/video."))
    is_video = models.BooleanField(default=False, help_text=_("Flag to indicate if media is a video."))
    upload_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['upload_order']
        verbose_name = "Media Upload"
        verbose_name_plural = "Media Uploads"

    def __str__(self):
        return f"Media for Post #{self.post.id}"


class PostHashTag(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE)
    hashtag = models.ForeignKey(HashTag, on_delete=models.CASCADE)

    class Meta:
        verbose_name = "PostHashTag"
        verbose_name_plural = "PostHashTags"
        constraints = [
            models.UniqueConstraint(fields=['post', 'hashtag'], name='unique_post_hashtag')
        ]
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
        verbose_name = "Like"
        verbose_name_plural = "Likes"
        constraints = [
            models.UniqueConstraint(fields=['liked_by', 'post'], name='unique_liked_by_post')
        ]

        #creating database indexes to inprove query performance such as: PostLike.objects.filter(post=some_post)
        indexes = [
            models.Index(fields=['post']),
            models.Index(fields=['liked_by']),
        ]

    def __str__(self):
        return f"{self.liked_by.username} liked post {self.post}"


class Comment(models.Model):
    commented_by = models.ForeignKey(User, on_delete=models.CASCADE)
    content = models.CharField(max_length=1000, help_text=_("The actual comment on a post."))
    commented_at = models.DateTimeField(auto_now_add=True)
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comment_on_post')

    class Meta:
        verbose_name = "Comment"
        verbose_name_plural = "Comments"
        indexes = [
            models.Index(fields=['post', 'commented_at']),
        ]

    @property
    def comment_like_count(self):
        return self.like_on_comment.count()

    def __str__(self):
        return f"{self.commented_by.username} commented on post {self.post.id}"


class CommentLike(models.Model):
    liked_at = models.DateTimeField(auto_now_add=True)
    liked_by = models.ForeignKey(User, on_delete=models.CASCADE)
    comment = models.ForeignKey(Comment, on_delete=models.CASCADE, related_name='like_on_comment')

    class Meta:
        verbose_name = "CommentLike"
        verbose_name_plural = "CommentLikes"
        constraints = [
            models.UniqueConstraint(fields=['liked_by', 'comment'], name='unique_liked_by_comment')
        ]
        indexes = [
            models.Index(fields=['comment']),
            models.Index(fields=['liked_by']),
        ]

    def __str__(self):
        return f"{self.liked_by.username} liked comment #{self.comment.id} on post {self.comment.post.id}"
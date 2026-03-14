from django.db import models
from django.utils.translation import gettext_lazy as _

from accounts.models import User
from core.managers import PostManager

from rest_framework.exceptions import ValidationError


class Emotion(models.Model):
    emotion_emoji_name = models.CharField(max_length=20, unique=True)
    emotion_public_id = models.CharField(max_length=2056, help_text=_("Public id of the emoji"))

    upload_order = models.PositiveIntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-upload_order"]
        verbose_name = _("Emotion")
        verbose_name_plural = _("Emotions")

    def __str__(self):
        return self.emotion_emoji_name


class UserEmotion(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="emotions")
    emotion = models.ForeignKey("Emotion", on_delete=models.CASCADE, related_name="user_emotions")
    noted_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-noted_at']
        verbose_name = _("User Emotion")
        verbose_name_plural = _("User Emotions")

    def __str__(self):
        return f"{self.user.username} felt {self.emotion.emotion_emoji_name} at {self.noted_at}"


class HashTag(models.Model):
    name = models.CharField(max_length=50, unique=True)
    created_at = models.DateTimeField(auto_now_add=True)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='hashtag_creator')

    class Meta:
        verbose_name = _("Hashtag")
        verbose_name_plural = _("Hashtags")

    def __str__(self):
        return f"{self.name}"


class Post(models.Model):
    class VisibilityEnum(models.TextChoices):
        PUBLIC = 'public', _('Public')
        PRIVATE = 'private', _('Private')
        FRIENDS_ONLY = 'friends_only', _('Friends Only')
    
    class ModerationStatus(models.TextChoices):
        APPROVED = 'approved', 'Approved'
        PENDING_REVIEW = 'pending_review', 'Pending Review'
        BLOCKED = 'blocked', 'Blocked'

    caption = models.CharField(max_length=512, help_text=_("Text caption describing the post."), blank=True, null=True)
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

    #content moderation fields
    moderation_status = models.CharField(
        max_length=20,
        choices=ModerationStatus.choices,
        default=ModerationStatus.APPROVED,
    )
    moderation_score = models.FloatField(null=True, blank=True)
    moderation_label = models.CharField(max_length=100, blank=True)
    moderation_model = models.CharField(max_length=50, blank=True)
    moderation_reason = models.TextField(blank=True)

    class Meta:
        verbose_name = _("Post")
        verbose_name_plural = _("Posts")
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
        verbose_name = _("Media Upload")
        verbose_name_plural = _("Media Uploads")

    def __str__(self):
        return f"Media for Post #{self.post.id}"


class PostHashTag(models.Model):
    post = models.ForeignKey(Post, on_delete=models.CASCADE)
    hashtag = models.ForeignKey(HashTag, on_delete=models.CASCADE)

    class Meta:
        verbose_name = _("PostHashTag")
        verbose_name_plural = _("PostHashTags")
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
        verbose_name = _("Like")
        verbose_name_plural = _("Likes")
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
        verbose_name = _("Comment")
        verbose_name_plural = _("Comments")
        indexes = [
            models.Index(fields=['post', 'commented_at']),
        ]

    def __str__(self):
        return f"{self.commented_by.username} commented on post {self.post.id}"


class FriendRequest(models.Model):
    class RequestStatusEnum(models.TextChoices):
        PENDING = 'pending', _('Pending')
        ACCEPTED = 'accepted', _('Accepted')
        REJECTED = 'rejected', _('Rejected')
        DELETED = 'deleted', _('Deleted by sender')

    from_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='friend_requests_sent',
        help_text=_("The user who sent the friend request.")
    )
    to_user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='friend_requests_received',
        help_text=_("The user who received the friend request.")
    )
    status = models.CharField(max_length=10, choices=RequestStatusEnum.choices, default=RequestStatusEnum.PENDING,
        help_text=_("The current status of the friend request.")
    )

    created_at = models.DateTimeField(auto_now_add=True, help_text=_("The time when the friend request was created."))
    responded_at = models.DateTimeField(null=True, blank=True, help_text=_("The time when the friend request was accepted."))

    class Meta:
        verbose_name = _("Friend Request")
        verbose_name_plural = _("Friend Requests")
        constraints = [
            models.CheckConstraint(check=~models.Q(from_user=models.F('to_user')), name='no_self_request'), #blocking friend request to self
            models.UniqueConstraint(fields=['from_user', 'to_user'], name='unique_friend_request')
        ]

    def clean(self):
        if self.from_user == self.to_user:
            raise ValidationError(_("You cannot send a friend request to yourself."))

    def save(self, *args, **kwargs):
        #running full validation before saving to ensure clean() rules are applied
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.from_user.username} → {self.to_user.username} - ({self.status})"


class Friend(models.Model):
    user1 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='first_user_in_the_friendship')
    user2 = models.ForeignKey(User, on_delete=models.CASCADE, related_name='second_user_in_the_friendship')

    created_at = models.DateTimeField(auto_now_add=True) #for db
    accepted_at = models.DateTimeField(auto_now_add=True) #for ui, if batch friend create, data might be different

    is_blocked = models.BooleanField(default=False)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=['user1', 'user2'], name='unique_friendship'),
            models.CheckConstraint(check=~models.Q(user1=models.F('user2')), name='no_self_friendship'),
        ]

    def clean(self):
        if self.user1 == self.user2:
            raise ValidationError(_("You cannot have a friendship relationship with yourself."))

        #db level validation for unique friendship
        #ordering users so (B,A) becomes (A,B)
        if self.user1.id > self.user2.id:
            self.user1, self.user2 = self.user2, self.user1

    def save(self, *args, **kwargs):
        #running full validation before saving to ensure clean() rules are applied
        self.full_clean()
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.user1.username} ↔ {self.user2.username}"
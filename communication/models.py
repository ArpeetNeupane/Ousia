from django.db import models
from django.core.exceptions import ValidationError

import uuid

from accounts.models import User
from communication.managers import ChatManager

#######need to include deleted for user filter in manager or filter or view - i think has been done already in view's get queryset
####ill remove file uploads, reply to, and group logic (if its too much) to make it simpler, message serializer validation is left, first
#properly test conversation


class ConversationParticipant(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    conversation = models.ForeignKey('Conversation', on_delete=models.CASCADE)
    deleted_for_user = models.BooleanField(default=False)
    class Meta:
        unique_together = ('user', 'conversation')
        verbose_name = 'Conversation Participant'
        verbose_name_plural = 'Conversation Participants'

    def __str__(self):
        return f"{self.user.username} in {self.conversation}"


class Conversation(models.Model):
    """This model represents a conversation between users"""
    id = models.UUIDField(primary_key=True, editable=False, default=uuid.uuid4)
    participants = models.ManyToManyField(User, through='ConversationParticipant')
    is_group = models.BooleanField(default=False)
    group_name = models.CharField(max_length=100, null=True, blank=True)
    group_admin = models.ForeignKey(
        User, 
        on_delete=models.SET_NULL, 
        null=True, 
        blank=True, #the one who creates the group will be the admin
        related_name='group_admin'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_deleted = models.BooleanField(default=False)

    class Meta:
        ordering = ['-updated_at']
        verbose_name = 'Conversation'
        verbose_name_plural = 'Conversations'

    objects = ChatManager()

    def __str__(self):
        if self.is_group:
            return f"Group: {self.group_name}"
        participants = list(self.participants.order_by('id'))
        if len(participants) >= 2:
            return f"Chat: {participants[0].username} & {participants[1].username}"
        elif len(participants) == 1:
            return f"Chat: {participants[0].username}"
        return f"Conversation {self.id}"

    def clean(self):
        if self.is_group and not self.group_name:
            raise ValidationError("Group name is required for group conversations.")
        if not self.is_group and self.group_name:
            raise ValidationError("Group name should not be set for 1-on-1 conversations.")
        if not self.is_group and self.participants.count() > 2:
            raise ValidationError("1-on-1 conversations cannot have more than 2 participants.")

    def save(self, *args, **kwargs):
        #running full validation before saving to ensure clean() rules are applied
        self.full_clean()
        super().save(*args, **kwargs)

    def make_group_admin(self, user):
        if self.is_group and not self.group_admin:
            self.group_admin = user

    def get_other_participant(self, user):
        """This function is used to get the other participant in a 1-on-1 conversation"""
        if self.is_group:
            return None
        return self.participants.exclude(id=user.id).first()

    def add_participant(self, user):
        """This function is used to add a participant to the conversation"""
        self.participants.add(user)
        if self.participants.count() > 2:
            if not self.is_group:
                self.is_group = True
        self.save()

    def remove_participants(self, users_to_remove, admin_user, confirmation=False):
        """
        This function is used by Admin for removal of one or more participants.
        Triggers soft-delete if removal would leave only 1 or 0 participants.
        """
        if not self.is_group:
            raise ValidationError("Participant removal is only valid in group chats.")

        if not users_to_remove:
            raise ValidationError("No users provided for removal.")

        if self.group_admin != admin_user:
            raise ValidationError("Only the group admin can remove participants.")

        #ensuring it's a list or iterable
        if not isinstance(users_to_remove, (list, tuple, set)):
            users_to_remove = [users_to_remove]

        for user in users_to_remove:
            if user == self.group_admin:
                raise ValidationError("Admin cannot remove themselves. They must leave the group instead.")
            if user not in self.participants.all():
                raise ValidationError(f"{user.username} is not a participant of the conversation.")

        remaining_count = self.participants.count()
        to_remove_count = len(users_to_remove)

        #if this removal would leave 1 participants, treat as soft delete
        if remaining_count - to_remove_count <= 1:
            if confirmation:
                self.soft_delete()
            else:
                raise ValidationError(
                    "Removing these participants will delete the conversation. Please confirm."
                )
        else:
            for user in users_to_remove:
                self.participants.remove(user)
            self.save()

    def leave_group(self, user, confirmation=False):
        """Allows admin to leave, transferring admin or soft-deleting if only one participant."""
        if not self.is_group:
            raise ValidationError("Only group conversations support leaving.")

        #regular user can leave group with no problem
        if user != self.group_admin:
            self.participants.remove(user)
            self.save()
            return

        remaining = self.participants.exclude(id=user.id)
        if not remaining.exists():
            self.soft_delete()
            return

        if remaining.count() == 1:
            if confirmation:
                self.soft_delete()
            else:
                raise ValidationError("Leaving now will delete the conversation. Please confirm.")
        else:
            self.group_admin = remaining.first()
            self.participants.remove(user)
            self.save()

    def soft_delete(self):
        if not self.is_deleted: #idempotent
            self.is_deleted = True
            self.save()


class Message(models.Model):
    "This class represents a message in a conversation."
    class MessageTypes(models.TextChoices):
        TEXT = 'text', 'Text'
        IMAGE = 'image', 'Image'
        VIDEO = 'video', 'Video'
        SYSTEM = 'system', 'System'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    conversation = models.ForeignKey(
        Conversation,
        on_delete=models.CASCADE,
        related_name='message_in_convo'
    )
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='message_sender')
    content = models.TextField(max_length=4096)
    message_type = models.CharField(max_length=6, choices=MessageTypes.choices, default=MessageTypes.TEXT)
    file_attachment_public_url = models.CharField(max_length=255, null=True, blank=True, help_text="Cloudinary public ID for the uploaded file attachment.")
    reply_to = models.ForeignKey(
        'self', #a message can optionally point to another message
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='replies'
    )
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    is_edited = models.BooleanField(default=False)
    is_deleted = models.BooleanField(default=False)

    class Meta:
        ordering = ['created_at']
        verbose_name = 'Message'
        verbose_name_plural = 'Messages'

    def __str__(self):
        sender_name = getattr(self.sender, 'username', 'Unknown')
        return f"Message from {sender_name} in {self.conversation}"

    def clean(self):
        if self.message_type in [self.MessageTypes.IMAGE, self.MessageTypes.VIDEO] and not self.file_attachment_public_url:
            raise ValidationError("File attachment URL is required for image and video messages.")

        if self.message_type in [self.MessageTypes.TEXT, self.MessageTypes.SYSTEM] and not self.content:
            raise ValidationError("Content is required for text and system messages.")

        if self.reply_to and self.reply_to.conversation_id != self.conversation_id:
            raise ValidationError("Reply must be in the same conversation.")

    def save(self, *args, **kwargs):
        #running full validation before saving to ensure clean() rules are applied
        self.full_clean()
        super().save(*args, **kwargs)

    def soft_delete(self):
        if not self.is_deleted: #this makes it idempotent. without this line, even if a message is marked deleted, it will always trigger a save
            self.is_deleted = True
            self.content = "This message was deleted"
            self.save()
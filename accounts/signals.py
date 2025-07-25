from django.db.models.signals import post_save
from django.dispatch import receiver
from accounts.models import User, Profile

@receiver(post_save, sender=User)
def create_or_update_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(
            user=instance,
            synced_username=instance.username,
            synced_email=instance.email,
            synced_phone_number=instance.phone_number
        )
    else:
        profile, _ = Profile.objects.get_or_create(user=instance)
        profile.synced_username = instance.username
        profile.synced_email = instance.email
        profile.synced_phone_number = instance.phone_number
        profile.save()


#if Profile is updated, update synced fields of User(email, phone_number and username)
@receiver(post_save, sender=Profile)
def sync_profile_to_user(sender, instance, **kwargs):
    user = instance.user
    updated = False

    if instance.synced_username and instance.synced_username != user.username:
        user.username = instance.synced_username
        updated = True
    if instance.synced_email and instance.synced_email != user.email:
        user.email = instance.synced_email
        updated = True
    if instance.synced_phone_number and instance.synced_phone_number != user.phone_number:
        user.phone_number = instance.synced_phone_number
        updated = True

    if updated:
        user.save()
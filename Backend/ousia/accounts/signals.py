from django.db.models.signals import post_save
from django.dispatch import receiver
from accounts.models import User, Profile, AreaOfInterest
from accounts.interest_sync import ensure_hashtag_for_interest

@receiver(post_save, sender=User)
def create_or_update_profile(sender, instance, created, **kwargs):
    if created:
        Profile.objects.create(
            user=instance,
            synced_username=instance.username,
            synced_email=instance.email,
            synced_birth_date=instance.birth_date
        )
    else:
        profile, _ = Profile.objects.get_or_create(user=instance)
        profile.synced_username = instance.username
        profile.synced_email = instance.email
        profile.synced_birth_date = instance.birth_date
        profile.save()


#if Profile is updated, update synced fields of User(email, birth_date and username)
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
    if instance.synced_birth_date and instance.synced_birth_date != user.birth_date:
        user.birth_date = instance.synced_birth_date
        updated = True

    if updated:
        user.save()


@receiver(post_save, sender=AreaOfInterest)
def sync_interest_to_hashtag(sender, instance, **kwargs):
    ensure_hashtag_for_interest(instance.name, created_by=instance.created_by)
from django.db.models.functions import Lower

from accounts.models import AreaOfInterest, UserAreaOfInterest
from core.models import HashTag


def normalize_interest_name(value: str) -> str:
    return ''.join((value or '').strip().split()).lower()


def interest_to_hashtag_name(interest_name: str) -> str:
    normalized = normalize_interest_name(interest_name)
    return f"#{normalized}" if normalized else ""


def ensure_hashtag_for_interest(interest_name: str, created_by=None):
    hashtag_name = interest_to_hashtag_name(interest_name)
    if not hashtag_name:
        return None
    hashtag, _ = HashTag.objects.get_or_create(
        name=hashtag_name,
        defaults={'created_by': created_by},
    )
    return hashtag


def sync_all_interests_to_hashtags(created_by=None):
    for interest_name in AreaOfInterest.objects.values_list('name', flat=True):
        ensure_hashtag_for_interest(interest_name, created_by=created_by)


def get_user_interest_hashtag_ids(user):
    raw_interest_names = list(UserAreaOfInterest.objects.filter(user=user).values_list(
        'users_interest__name',
        flat=True,
    ))

    for interest_name in raw_interest_names:
        ensure_hashtag_for_interest(interest_name)

    normalized_hashtags = {
        interest_to_hashtag_name(name).lower()
        for name in raw_interest_names
        if name
    }

    if not normalized_hashtags:
        return []

    return list(
        HashTag.objects.annotate(lower_name=Lower('name'))
        .filter(lower_name__in=normalized_hashtags)
        .values_list('id', flat=True)
    )
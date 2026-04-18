from communication.models import Conversation

def check_for_existing_one_on_one_conversation(users):
    """
    Checks whether a one-on-one conversation already exists between two users.

    Logic:
    - Only considers exactly 2 users
    - Filters non-group conversations where either user is a participant
    - Iterates through results to find a conversation containing both users only

    Note:
    Initial queryset may include conversations where only one of the users
    is present, so an explicit participant match check is required.

    Args:
        users (Iterable[User]): List or iterable of exactly two user instances.

    Returns:
        Conversation | None: Existing one-on-one conversation if found, else None.
    """
    
    if len(users) != 2:
        return False

    user_ids = sorted([user.id for user in users])

    #finding all possible conversations for both users
    #possible_conversations may include 1-on-1 conversations involving either of the users, but not necessarily both together
    possible_conversations = Conversation.objects.filter(
        is_group=False,
        participants__id__in=user_ids
    ).distinct()

    #narrowing down to the exact 2 users
    for convo in possible_conversations:
        convo_user_ids = sorted([u.id for u in convo.participants.all()])
        if convo_user_ids == user_ids:
            return convo
    return None
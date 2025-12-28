from communication.models import Conversation

def check_for_existing_one_on_one_conversation(users):
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
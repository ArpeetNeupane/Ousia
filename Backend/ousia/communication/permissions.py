from rest_framework.permissions import BasePermission

class BelongsToConversation(BasePermission):
    """
    Custom permission to allow access to:
    1. Participants belonging to a certain conversation.
    """
    def has_object_permission(self, request, view, obj):
        return obj.participants.filter(id=request.user.id).exists()


class IsAdminOfConversation(BasePermission):
    """
    Custom permission to allow access to:
    1. The group admin of a certain conversation.
    """
    def has_object_permission(self, request, view, obj):
        return obj.group_admin_id == request.user.id
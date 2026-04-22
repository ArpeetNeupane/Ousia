from rest_framework.permissions import BasePermission

class OwnsObjectOrAdmin(BasePermission):
    """
    Custom permission to allow access to:
    1. Object owners (via 'user' or 'created_by' fields)
    2. Admin/superuser accounts
    """

    def has_object_permission(self, request, view, obj):
        if request.user and request.user.is_staff:
            return True

        owner = getattr(obj, 'user', None) or getattr(obj, 'created_by', None) or getattr(obj, 'posted_by', None)
        return owner == request.user


class OwnsMediaOrAdmin(BasePermission):
    """Allows deleting media if the requester owns the parent post or is staff."""

    def has_object_permission(self, request, view, obj):
        if request.user and request.user.is_staff:
            return True

        post = getattr(obj, 'post', None)
        posted_by = getattr(post, 'posted_by', None)
        return posted_by == request.user


class IsOwnerOfLike(BasePermission):
    """
    Custom permission to only allow users to delete a like object belonging to them.
    """
    def has_object_permission(self, request, view, obj):
        return obj.liked_by == request.user
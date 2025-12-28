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
from rest_framework.permissions import BasePermission, IsAuthenticated, IsAdminUser

class IsAuthenticatedOrAdmin(BasePermission):
    def has_permission(self, request, view):
        return IsAuthenticated().has_permission(request, view) or IsAdminUser().has_permission(request, view)


class IsOwnerOfProfile(BasePermission):
    """
    Custom permission to only allow users to edit their own profile.
    """
    def has_object_permission(self, request, view, obj):
        return obj == request.user


class CreatorOfInterest(BasePermission):
    """
    Custom permission to only allow users to edit interest created by them.
    """
    def has_object_permission(self, request, view, obj):
        return obj.created_by == request.user


class IsOwnerOfUserInterest(BasePermission):
    """
    Custom permission to only allow users to retrieve and delete user interest belonging to them.
    """
    def has_object_permission(self, request, view, obj):
        return obj.user == request.user
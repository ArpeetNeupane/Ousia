from rest_framework.pagination import LimitOffsetPagination

class DefaultPagination(LimitOffsetPagination):
    default_limit = 10
    max_limit = 100 #via query params


class HashTagPagination(LimitOffsetPagination):
    default_limit = 30
    max_limit = 100

class NotificationPagination(LimitOffsetPagination):
    default_limit = 15
    max_limit = 100
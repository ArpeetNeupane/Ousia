from rest_framework.pagination import LimitOffsetPagination

class CommunicationPagination(LimitOffsetPagination):
    default_limit = 20
    max_limit = 200 #via query params
import django_filters

from communication.models import Conversation

from django.db.models import Q


class ConversationFilter(django_filters.FilterSet):
    query = django_filters.CharFilter(method='filter_by_username_or_group')

    class Meta:
        model=Conversation
        fields = []

    def filter_by_username_or_group(self, queryset, name, value):
        return queryset.filter(
            Q(group_name__icontains=value) |
            Q(participants__username__icontains=value)
        ).distinct()
import django_filters
from django.db.models import Q, Count #Q=query object
from django.contrib.postgres.search import SearchVector

from core.models import Post

class PostFilter(django_filters.FilterSet):
    posted_by = django_filters.CharFilter(field_name='posted_by__username', lookup_expr='exact')
    hashtag_any = django_filters.CharFilter(method='filter_any_hashtag') #eg: ?hashtag_any=#fun,#travel - matches posts with fun or travel
    hashtag_all = django_filters.CharFilter(method='filter_all_hashtag') #eg: ?hashtag_all=#fun,#travel - matches posts with fun AND travel, includes any other filters
    created_after = django_filters.DateTimeFilter(field_name='created_at', lookup_expr='gte')
    created_before = django_filters.DateTimeFilter(field_name='created_at', lookup_expr='lte')
    visibility = django_filters.ChoiceFilter(choices=Post.VisibilityEnum.choices)
    caption = django_filters.CharFilter(method='filter_caption_search', label="Full-text caption search")

    class Meta:
        model=Post
        fields = ['posted_by', 'hashtag_any', 'hashtag_all', 'created_after', 'created_before', 'caption']

    def filter_any_hashtag(self, queryset, name, value):
        hashtags = [tag.strip() for tag in value.split(',') if tag.strip()] #using if to remove empty strings
        return queryset.filter(type_of_post__name__in=hashtags).distinct() #distinct prevents duplicate rows if a post matches multiple hashtags

    def filter_all_hashtag(self, queryset, name, value):
        hashtags = [tag.strip() for tag in value.split(',') if tag.strip()]
        hashtag_count = len(set(hashtags))

        return (
            queryset.filter(type_of_post__name__in=hashtags) #filtering to posts that contain at least one of the input hashtags
            .annotate(matched_tags=Count('type_of_post', filter=Q(type_of_post__name__in=hashtags), distinct=True)) #for each post in the filtered result, counting how many of its hashtags are in the user input(query_params) list
            .filter(matched_tags=hashtag_count) #only keeping posts where number of matching hashtags = number the query params asked for.
        )

    def filter_caption_search(self, queryset, name, value):
        return queryset.annotate(
            search=SearchVector('caption')
        ).filter(search=value)
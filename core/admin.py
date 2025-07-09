from django.contrib import admin

from core.models import *

admin.site.register(Emotion)
admin.site.register(HashTag)
admin.site.register(Post)
admin.site.register(FriendRequest)
admin.site.register(Friend)
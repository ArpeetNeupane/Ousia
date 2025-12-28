"""
ASGI config for myproject project.

It exposes the ASGI callable as a module-level variable named ``application``.

For more information on this file, see
https://docs.djangoproject.com/en/5.2/howto/deployment/asgi/
"""

import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "myproject.settings")

django_asgi_app = get_asgi_application()

from channels.routing import (
    ProtocolTypeRouter,
    URLRouter #urls.py but for websockets
)
from channels.auth import AuthMiddlewareStack #adds Django authentication to WebSocket connections

from communication.routing import websocket_urlpatterns


application = ProtocolTypeRouter({
    "http": django_asgi_app,
    "websocket": AuthMiddlewareStack(
        URLRouter(
            websocket_urlpatterns
        )
    ),
})

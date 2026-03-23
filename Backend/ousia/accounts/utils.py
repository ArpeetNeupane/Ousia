from rest_framework.throttling import UserRateThrottle

class SuccessfulUpdateThrottle(UserRateThrottle):
    scope = 'update_password'

    def __init__(self):
        super().__init__()
        self.key = None

    def allow_request(self, request, view):
        #always allowing the request first
        self.key = self.get_cache_key(request, view)
        return True

    def wait(self):
        return super().wait()

    def throttle_success(self):
        if self.key:
            self.history = self.cache.get(self.key, [])
            self.history.append(self.timer())
            self.cache.set(self.key, self.history, self.duration)
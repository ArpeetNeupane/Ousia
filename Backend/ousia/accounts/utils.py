from rest_framework.throttling import UserRateThrottle


class SuccessfulUpdateThrottle(UserRateThrottle):
    """Rate-limit *successful* password updates.

    This throttle does **not** count failed attempts (e.g., wrong current password).
    It only records a hit when `throttle_success()` is explicitly called after a
    successful update.
    """

    scope = 'update_password'

    def allow_request(self, request, view):
        #computing key + load existing success history.
        self.key = self.get_cache_key(request, view)
        if self.key is None:
            return True

        self.history = self.cache.get(self.key, [])
        self.now = self.timer()

        #DRF stores the most recent timestamp at index 0.
        while self.history and self.history[-1] <= self.now - self.duration:
            self.history.pop()

        #blocking if we already have a recorded success within the window
        if len(self.history) >= self.num_requests:
            return self.throttle_failure()

        #allowing, but not writing to cache yet (success-only throttle).
        return True

    def throttle_success(self):
        """Record a successful request for this throttle key."""

        key = getattr(self, 'key', None)
        if not key:
            return

        self.history = self.cache.get(key, [])
        self.now = self.timer()

        while self.history and self.history[-1] <= self.now - self.duration:
            self.history.pop()

        self.history.insert(0, self.now)
        self.cache.set(key, self.history, self.duration)
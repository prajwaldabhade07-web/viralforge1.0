import threading
import time
from collections import defaultdict, deque

from app.errors import AppError


class RateLimiter:
    """In-memory sliding-window limiter. Adequate for a single-process local MVP."""

    def __init__(self):
        self._hits: dict[tuple[str, str], deque] = defaultdict(deque)
        self._lock = threading.Lock()

    def hit(self, rule: str, key: str, limit: int, window_seconds: int) -> None:
        now = time.monotonic()
        with self._lock:
            q = self._hits[(rule, key)]
            while q and q[0] <= now - window_seconds:
                q.popleft()
            if len(q) >= limit:
                retry = max(1, int(q[0] + window_seconds - now))
                raise AppError(429, "rate_limited", "Too many requests. Please wait and try again.",
                               headers={"Retry-After": str(retry)})
            q.append(now)

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()

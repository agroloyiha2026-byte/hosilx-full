from __future__ import annotations
from collections import defaultdict, deque


class RateLimiter:
    """Foydalanuvchi bo'yicha oyna ichidagi so'rovlar sonini cheklaydi (xotirada)."""

    def __init__(self, limit: int = 10, per: float = 10.0):
        self.limit, self.per = limit, per
        self._hits: dict[int, deque[float]] = defaultdict(deque)

    def allow(self, user_id: int, now: float) -> bool:
        q = self._hits[user_id]
        while q and now - q[0] > self.per:
            q.popleft()
        if len(q) >= self.limit:
            return False
        q.append(now)
        return True

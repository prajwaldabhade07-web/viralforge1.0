"""Bearer-token verification through Supabase Auth (server-side `get_user`)."""

import hashlib
import time
from dataclasses import dataclass
from typing import Protocol

from app.errors import AppError


@dataclass(frozen=True)
class CurrentUser:
    id: str
    email: str | None


class AuthVerifier(Protocol):
    def verify(self, token: str) -> CurrentUser: ...


class SupabaseAuthVerifier:
    """Asks Supabase to validate the access token. Works with any JWT signing setup.
    Successful lookups are cached briefly to avoid a network call on every request."""

    def __init__(self, client, ttl_seconds: int = 30):
        self.client = client
        self.ttl = ttl_seconds
        self._cache: dict[str, tuple[float, CurrentUser]] = {}

    def verify(self, token: str) -> CurrentUser:
        key = hashlib.sha256(token.encode()).hexdigest()
        hit = self._cache.get(key)
        if hit and hit[0] > time.monotonic():
            return hit[1]
        try:
            res = self.client.auth.get_user(token)
            user = getattr(res, "user", None)
            if user is None:
                raise AppError(
                    401, "invalid_token", "Your session is invalid or has expired. Sign in again."
                )
        except AppError:
            raise
        except Exception as e:  # noqa: BLE001
            status = getattr(e, "status", None)
            if status in (400, 401, 403) or "Auth" in type(e).__name__:
                raise AppError(
                    401, "invalid_token", "Your session is invalid or has expired. Sign in again."
                ) from e
            raise AppError(
                503,
                "auth_unavailable",
                "Could not reach the authentication service. Try again shortly.",
            ) from e
        cu = CurrentUser(id=str(user.id), email=getattr(user, "email", None))
        if len(self._cache) > 1000:
            self._cache.clear()
        self._cache[key] = (time.monotonic() + self.ttl, cu)
        return cu

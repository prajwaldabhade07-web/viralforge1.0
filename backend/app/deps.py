from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.auth import CurrentUser
from app.container import Container
from app.errors import AppError

bearer = HTTPBearer(auto_error=False, description="Supabase access token (JWT)")


def get_container(request: Request) -> Container:
    return request.app.state.container


def current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    c: Container = Depends(get_container),
) -> CurrentUser:
    if creds is None or creds.scheme.lower() != "bearer" or not creds.credentials:
        raise AppError(401, "not_authenticated", "Sign in to continue.", headers={"WWW-Authenticate": "Bearer"})
    user = c.auth.verify(creds.credentials)
    c.limiter.hit("global", user.id, c.settings.rate_limit_per_minute, 60)
    return user


def owned_project(c: Container, user_id: str, project_id: str) -> dict:
    from app.errors import not_found

    rows = c.repo.select("projects", {"id": project_id, "user_id": user_id}, limit=1)
    if not rows:
        raise not_found("Project")
    return rows[0]

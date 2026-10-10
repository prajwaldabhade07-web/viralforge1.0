from fastapi import APIRouter, Depends
from fastapi.responses import JSONResponse

from app.auth import CurrentUser
from app.container import Container
from app.deps import current_user, get_container
from app.schemas import MeOut, PublicConfig

router = APIRouter()


@router.get("/health", tags=["health"], summary="Liveness check")
def health():
    return {"status": "ok", "service": "viralforge-experiment"}


@router.get("/health/ready", tags=["health"], summary="Readiness: configuration, database and Gemini model")
def ready(c: Container = Depends(get_container)):
    checks: dict = {"config_missing": c.settings.missing_required()}
    try:
        c.repo.count("projects")
        checks["database"] = {"ok": True}
    except Exception:  # noqa: BLE001
        checks["database"] = {"ok": False, "message": "Database unreachable or migrations not applied."}
    st = c.refresh_model_status(max_age=30)
    checks["gemini_model"] = {"ok": st.ok, "model": c.settings.gemini_model, "message": st.message}
    ok = not checks["config_missing"] and checks["database"]["ok"] and st.ok
    return JSONResponse({"status": "ready" if ok else "degraded", "checks": checks}, status_code=200 if ok else 503)


@router.get("/config", response_model=PublicConfig, tags=["health"], summary="Public upload limits")
def public_config(c: Container = Depends(get_container)):
    s = c.settings
    return PublicConfig(max_upload_mb=s.max_upload_mb, min_video_seconds=s.min_video_seconds,
                        max_video_seconds=s.max_video_seconds, allowed_extensions=s.extension_list,
                        model=s.gemini_model)


@router.get("/me", response_model=MeOut, tags=["auth"], summary="Current authenticated user")
def me(user: CurrentUser = Depends(current_user)):
    return MeOut(id=user.id, email=user.email)

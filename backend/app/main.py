import faulthandler
import logging
import sys
import threading
import uuid
from contextlib import asynccontextmanager
from logging.handlers import RotatingFileHandler
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.config import get_settings
from app.container import Container, build_default_container
from app.errors import AppError
from app.routers import analyses, health, projects, videos
from app.services.safety import RedactingFilter
from app.services.worker import Worker

VERSION = "1.0.0"
log = logging.getLogger("viralforge")


def _error(request: Request, status: int, code: str, message: str, details=None, headers=None):
    rid = getattr(request.state, "request_id", None)
    return JSONResponse(
        {"error": {"code": code, "message": message, "details": details, "request_id": rid}},
        status_code=status,
        headers=headers,
    )


def _enable_crash_log() -> None:
    """Writes backend/logs/backend.log (rotating) and records uncaught errors and hard crashes,
    so "the backend stopped" can always be explained afterwards. Never stops the app on failure."""
    try:
        logs = Path(__file__).resolve().parents[1] / "logs"
        logs.mkdir(exist_ok=True)
        root = logging.getLogger()
        if not any(isinstance(h, RotatingFileHandler) for h in root.handlers):
            fh = RotatingFileHandler(
                logs / "backend.log", maxBytes=2_000_000, backupCount=3, encoding="utf-8"
            )
            fh.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
            root.addHandler(fh)
        crash = open(logs / "crash.log", "a", buffering=1, encoding="utf-8")  # noqa: SIM115
        faulthandler.enable(file=crash, all_threads=True)

        def _thread_hook(args):
            log.error(
                "Uncaught error in thread %s",
                getattr(args.thread, "name", "?"),
                exc_info=(args.exc_type, args.exc_value, args.exc_traceback),
            )

        threading.excepthook = _thread_hook
        sys.excepthook = lambda t, v, tb: log.error("Uncaught error", exc_info=(t, v, tb))
    except Exception:  # noqa: BLE001
        log.warning("Could not set up the crash log; continuing without it")


def create_app(container: Container | None = None, *, start_worker: bool | None = None) -> FastAPI:
    settings = container.settings if container else get_settings()
    logging.basicConfig(
        level=settings.log_level.upper(), format="%(asctime)s %(levelname)s %(name)s: %(message)s"
    )
    if container is None:  # a real run (not a test): keep a crash log that survives the terminal
        _enable_crash_log()
    for h in logging.getLogger().handlers:
        h.addFilter(RedactingFilter())

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        c = getattr(app.state, "container", None) or build_default_container(settings)
        app.state.container = c
        st = c.refresh_model_status()
        (log.info if st.ok else log.error)("Gemini model check: %s", st.message)
        worker = None
        if settings.worker_enabled if start_worker is None else start_worker:
            worker = Worker(c)
            worker.start()
            app.state.worker = worker
        yield
        if worker:
            worker.stop()

    app = FastAPI(
        title="ViralForge Experimental API",
        version=VERSION,
        lifespan=lifespan,
        description="Video-first AI analysis of short-form content. All routes except /health, "
        "/health/ready and /config require a Supabase bearer token.",
    )
    if container is not None:
        app.state.container = container

    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_methods=["GET", "POST", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type"],
        expose_headers=["Retry-After", "X-Request-ID"],
    )

    @app.middleware("http")
    async def request_context(request: Request, call_next):
        request.state.request_id = (
            request.headers.get("x-request-id", "")[:64] or uuid.uuid4().hex[:12]
        )
        response = await call_next(request)
        response.headers["X-Request-ID"] = request.state.request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Cache-Control"] = "no-store"
        return response

    @app.exception_handler(AppError)
    async def _app_error(request: Request, exc: AppError):
        return _error(request, exc.status_code, exc.code, exc.message, exc.details, exc.headers)

    @app.exception_handler(RequestValidationError)
    async def _validation(request: Request, exc: RequestValidationError):
        details = [
            {"field": ".".join(str(p) for p in e["loc"] if p != "body"), "message": e["msg"]}
            for e in exc.errors()
        ]
        return _error(request, 422, "validation_error", "Some fields are invalid.", details)

    @app.exception_handler(StarletteHTTPException)
    async def _http(request: Request, exc: StarletteHTTPException):
        code = {404: "not_found", 405: "method_not_allowed"}.get(exc.status_code, "http_error")
        return _error(request, exc.status_code, code, str(exc.detail))

    @app.exception_handler(Exception)
    async def _unhandled(request: Request, exc: Exception):
        log.exception("Unhandled error on %s %s", request.method, request.url.path)
        return _error(
            request, 500, "internal_error", "Something went wrong on our side. Try again."
        )

    for r in (health.router, projects.router, videos.router, analyses.router):
        app.include_router(r, prefix="/api/v1")
    return app


def app_factory() -> FastAPI:  # uvicorn app.main:app_factory --factory
    return create_app()

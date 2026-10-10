"""Dependency container: everything external is injected, so tests substitute fakes."""
import time
from dataclasses import dataclass, field

from app.auth import AuthVerifier, SupabaseAuthVerifier
from app.config import Settings
from app.errors import AppError
from app.rate_limit import RateLimiter
from app.repo import Repo, SupabaseRepo
from app.services.gemini import GeminiGateway, GoogleGenaiGateway, ModelUnavailable
from app.storage import Storage, SupabaseStorage


@dataclass
class ModelStatus:
    ok: bool = False
    message: str = "Model availability has not been checked yet."
    checked_at: float = 0.0


@dataclass
class Container:
    settings: Settings
    repo: Repo
    storage: Storage
    auth: AuthVerifier
    gemini: GeminiGateway
    limiter: RateLimiter = field(default_factory=RateLimiter)
    model_status: ModelStatus = field(default_factory=ModelStatus)

    def refresh_model_status(self, max_age: float = 0.0, max_age_bad: float = 15.0) -> ModelStatus:
        """Re-verify the model through the API unless a recent result is cached.
        Failures are re-checked at most every `max_age_bad` seconds to avoid hammering the API."""
        st = self.model_status
        age = time.monotonic() - st.checked_at if st.checked_at else None
        if age is not None and max_age and ((st.ok and age < max_age) or (not st.ok and age < max_age_bad)):
            return st
        try:
            self.gemini.check_model()
            self.model_status = ModelStatus(True, f"Model '{self.settings.gemini_model}' is available.", time.monotonic())
        except ModelUnavailable as e:
            self.model_status = ModelStatus(False, str(e), time.monotonic())
        return self.model_status

    def require_model(self) -> None:
        st = self.refresh_model_status(max_age=60)
        if not st.ok:
            raise AppError(503, "model_unavailable", st.message)


def build_default_container(settings: Settings) -> Container:
    missing = settings.missing_required()
    if missing:
        raise RuntimeError(
            "Missing configuration: " + ", ".join(missing) + ". Copy .env.example to .env and fill in the values."
        )
    repo = SupabaseRepo(settings.supabase_url, settings.supabase_service_role_key)
    return Container(
        settings=settings,
        repo=repo,
        storage=SupabaseStorage(repo.client, settings.storage_bucket),
        auth=SupabaseAuthVerifier(repo.client),
        gemini=GoogleGenaiGateway(
            settings.gemini_api_key, settings.gemini_model,
            timeout_s=settings.gemini_timeout_seconds,
            file_ready_timeout_s=settings.gemini_file_ready_timeout_seconds,
        ),
    )

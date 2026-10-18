"""Environment-driven settings. Values come from the repo-root .env file or real env vars."""

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

ROOT = Path(__file__).resolve().parents[2]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=str(ROOT / ".env"), env_file_encoding="utf-8", extra="ignore"
    )

    app_env: str = "development"
    log_level: str = "INFO"

    # Supabase (service-role key is backend-only and must never reach the frontend).
    supabase_url: str = ""
    supabase_service_role_key: str = ""
    storage_bucket: str = "videos"

    # Gemini
    gemini_api_key: str = ""
    gemini_model: str = "gemini-3.8-flash"
    gemini_timeout_seconds: int = 120
    gemini_file_ready_timeout_seconds: int = 300
    # Speed settings. Set to empty in .env to disable (e.g. GEMINI_THINKING_LEVEL=)
    gemini_thinking_level: str = "low"
    gemini_media_resolution: str = "low"
    # Run the safety check and the analysis at the same time
    parallel_moderation: bool = True

    # Upload limits
    max_upload_mb: int = 50
    min_video_seconds: float = 1.0
    max_video_seconds: float = 90.0
    allowed_extensions: str = "mp4,webm,mov"
    signed_url_ttl_seconds: int = 300

    # Web
    cors_origins: str = "http://localhost:5173,http://127.0.0.1:5173"

    # Worker
    worker_enabled: bool = True
    worker_poll_seconds: float = 2.0
    job_lease_seconds: int = 900
    max_job_attempts: int = 3

    # Rate limits (per user)
    rate_limit_per_minute: int = 120
    upload_limit_per_hour: int = 20
    analysis_limit_per_hour: int = 20

    @property
    def max_upload_bytes(self) -> int:
        return self.max_upload_mb * 1024 * 1024

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def extension_list(self) -> list[str]:
        return [
            e.strip().lower().lstrip(".") for e in self.allowed_extensions.split(",") if e.strip()
        ]

    def missing_required(self) -> list[str]:
        names = {
            "SUPABASE_URL": self.supabase_url,
            "SUPABASE_SERVICE_ROLE_KEY": self.supabase_service_role_key,
            "GEMINI_API_KEY": self.gemini_api_key,
        }
        return [k for k, v in names.items() if not v or v.startswith("your-") or "YOUR_" in v]


@lru_cache
def get_settings() -> Settings:
    return Settings()

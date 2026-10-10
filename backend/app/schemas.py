"""Public API request/response models."""
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator, model_validator

Platform = Literal["instagram_reels", "tiktok", "youtube_shorts"]
JobStatus = Literal["queued", "processing", "completed", "failed"]


def _strip(v):
    return v.strip() if isinstance(v, str) else v


class ErrorBody(BaseModel):
    code: str
    message: str
    details: Any | None = None
    request_id: str | None = None


class ErrorResponse(BaseModel):
    error: ErrorBody


class ProjectCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    platform: Platform | None = None
    niche: str | None = Field(default=None, max_length=100)
    target_audience: str | None = Field(default=None, max_length=200)

    _s = field_validator("name", "description", "niche", "target_audience", mode="before")(_strip)


class ProjectUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    description: str | None = Field(default=None, max_length=500)
    platform: Platform | None = None
    niche: str | None = Field(default=None, max_length=100)
    target_audience: str | None = Field(default=None, max_length=200)

    _s = field_validator("name", "description", "niche", "target_audience", mode="before")(_strip)


class ProjectOut(BaseModel):
    id: str
    name: str
    description: str | None = None
    platform: Platform | None = None
    niche: str | None = None
    target_audience: str | None = None
    analysis_count: int = 0
    created_at: str
    updated_at: str


class VideoOut(BaseModel):
    id: str
    project_id: str
    original_filename: str
    mime_type: str
    size_bytes: int
    duration_seconds: float | None = None
    created_at: str


class SignedUrlOut(BaseModel):
    url: str
    expires_in: int


class AnalysisCreate(BaseModel):
    input_type: Literal["video", "script"] = "video"
    video_id: str | None = None
    script_text: str | None = Field(default=None, max_length=8000)
    platform: Platform
    niche: str = Field(min_length=1, max_length=100)
    target_audience: str = Field(min_length=1, max_length=200)
    caption: str | None = Field(default=None, max_length=2200)

    _s = field_validator("niche", "target_audience", "caption", "script_text", mode="before")(_strip)

    @model_validator(mode="after")
    def _check_input(self):
        if self.input_type == "video":
            if not self.video_id:
                raise ValueError("video_id is required for video analysis")
            if self.script_text:
                raise ValueError("script_text is only allowed for script analysis")
        else:
            if not self.script_text or len(self.script_text) < 20:
                raise ValueError("script_text must be at least 20 characters for script analysis")
            if self.video_id:
                raise ValueError("video_id is not allowed for script analysis")
        return self


class JobOut(BaseModel):
    id: str
    project_id: str
    project_name: str | None = None
    video_id: str | None = None
    input_type: Literal["video", "script"]
    platform: Platform
    niche: str
    target_audience: str
    caption: str | None = None
    status: JobStatus
    stage: str
    progress: int
    attempts: int
    max_attempts: int
    error_code: str | None = None
    error_message: str | None = None
    retryable: bool = False
    scores: dict[str, int] | None = None
    created_at: str
    started_at: str | None = None
    completed_at: str | None = None


class JobDetailOut(JobOut):
    report: dict[str, Any] | None = None


class ReportOut(BaseModel):
    id: str
    job_id: str
    project_id: str
    scores: dict[str, int]
    report: dict[str, Any]
    model: str
    created_at: str


class Page(BaseModel):
    items: list[Any]
    total: int
    limit: int
    offset: int


class ProjectPage(Page):
    items: list[ProjectOut]


class VideoPage(Page):
    items: list[VideoOut]


class JobPage(Page):
    items: list[JobOut]


class MeOut(BaseModel):
    id: str
    email: str | None = None


class PublicConfig(BaseModel):
    max_upload_mb: int
    min_video_seconds: float
    max_video_seconds: float
    allowed_extensions: list[str]
    model: str

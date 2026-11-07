"""Schemas the model must fill. Kept free of Field constraints/defaults so they convert cleanly
to Gemini's response schema; ranges and completeness are enforced by the validators below."""

from typing import Literal

from pydantic import BaseModel, ValidationError, field_validator, model_validator

from app.services.scoring import DIMENSION_KEYS

DimensionKey = Literal[
    "hook_strength",
    "clarity",
    "emotional_appeal",
    "entertainment_value",
    "information_value",
    "audience_retention",
    "shareability",
]
ObservationArea = Literal[
    "visual_storytelling", "pacing", "opening_hook", "audio_speech", "on_screen_text"
]
ModerationCategory = Literal[
    "sexual_content",
    "sexual_content_involving_minors",
    "graphic_violence",
    "violent_extremism",
    "hate_or_harassment",
    "self_harm_promotion",
    "illegal_activity",
    "dangerous_weapons_or_drugs",
    "fraud_or_scam",
    "privacy_violation",
    "other",
]


def _in_range(v: int, lo: int, hi: int, what: str) -> int:
    if isinstance(v, bool) or not lo <= v <= hi:
        raise ValueError(f"{what} must be an integer from {lo} to {hi}")
    return v


class DimensionScore(BaseModel):
    key: DimensionKey
    score: int
    rationale: str

    @field_validator("score")
    @classmethod
    def _score(cls, v: int) -> int:
        return _in_range(v, 1, 10, "score")


class Observation(BaseModel):
    area: ObservationArea
    observation: str
    evidence: str


class Recommendation(BaseModel):
    priority: int
    title: str
    detail: str
    expected_impact: Literal["high", "medium", "low"]

    @field_validator("priority")
    @classmethod
    def _p(cls, v: int) -> int:
        return _in_range(v, 1, 20, "priority")


class ContentAnalysis(BaseModel):
    content_summary: str
    dimensions: list[DimensionScore]
    strengths: list[str]
    weaknesses: list[str]
    recommendations: list[Recommendation]
    observations: list[Observation]
    confidence: Literal["low", "medium", "high"]
    confidence_note: str

    @model_validator(mode="after")
    def _complete(self):
        keys = sorted(d.key for d in self.dimensions)
        if keys != sorted(DIMENSION_KEYS):
            raise ValueError(
                "dimensions must contain each of the seven dimension keys exactly once"
            )
        for name in ("strengths", "weaknesses", "recommendations"):
            if not 1 <= len(getattr(self, name)) <= 10:
                raise ValueError(f"{name} must contain 1 to 10 items")
        if not self.content_summary.strip():
            raise ValueError("content_summary must not be empty")
        return self


_ACTIONS = ("share", "like", "comment", "follow", "keep_scrolling")
_CATEGORIES = set(ModerationCategory.__args__)  # type: ignore[attr-defined]


def _clamp_int(v, lo: int, hi: int, what: str) -> int:
    """Persona and moderation output is forgiving: a stray 0, 11 or 7.0 is repaired, not fatal."""
    if isinstance(v, bool) or v is None:
        raise ValueError(f"{what} must be a number")
    try:
        n = round(float(v))
    except (TypeError, ValueError) as e:
        raise ValueError(f"{what} must be a number") from e
    return max(lo, min(hi, n))


def _text(v) -> str:
    return "" if v is None else str(v)


class PersonaReaction(BaseModel):
    persona_id: str
    first_impression: str
    interest_level: int
    likely_action: Literal["share", "like", "comment", "follow", "keep_scrolling"]
    would_finish: bool
    reaction: str
    concern: str

    @field_validator("persona_id", mode="before")
    @classmethod
    def _pid(cls, v):
        return _text(v).strip()

    @field_validator("first_impression", "reaction", "concern", mode="before")
    @classmethod
    def _strs(cls, v):
        return _text(v)

    @field_validator("interest_level", mode="before")
    @classmethod
    def _i(cls, v):
        return _clamp_int(v, 1, 10, "interest_level")

    @field_validator("likely_action", mode="before")
    @classmethod
    def _a(cls, v):
        s = _text(v).strip().lower().replace("-", "_").replace(" ", "_")
        if s in _ACTIONS:
            return s
        for a in _ACTIONS[:4]:
            if a in s:
                return a
        return "keep_scrolling"

    @field_validator("would_finish", mode="before")
    @classmethod
    def _w(cls, v):
        return False if v is None else v


class PersonaSimulation(BaseModel):
    reactions: list[PersonaReaction]

    @field_validator("reactions", mode="before")
    @classmethod
    def _keep_usable(cls, v):
        """One malformed reaction must not throw away the other nine: drop it (it is then reported
        as missing and re-requested). Only a reply with no usable reaction at all is rejected."""
        if not isinstance(v, list):
            raise ValueError("reactions must be a list")
        good = []
        for item in v:
            if isinstance(item, PersonaReaction):
                good.append(item)
                continue
            try:
                good.append(PersonaReaction.model_validate(item))
            except ValidationError:
                continue
        if not good:
            raise ValueError("no usable persona reactions")
        return good


class ModerationVerdict(BaseModel):
    allowed: bool
    categories: list[ModerationCategory]
    reason: str

    @field_validator("allowed", mode="before")
    @classmethod
    def _allowed(cls, v):
        if isinstance(v, str):
            t = v.strip().lower()
            if t in ("true", "yes", "allowed", "1"):
                return True
            if t in ("false", "no", "blocked", "0"):
                return False
        return v

    @field_validator("categories", mode="before")
    @classmethod
    def _cats(cls, v):
        if v is None:
            return []
        if isinstance(v, str):
            v = [v]
        out: list[str] = []
        for c in v:
            key = _text(c).strip().lower().replace("-", "_").replace(" ", "_")
            key = key if key in _CATEGORIES else "other"
            if key not in out:
                out.append(key)
        return out

    @field_validator("reason", mode="before")
    @classmethod
    def _reason(cls, v):
        return _text(v)

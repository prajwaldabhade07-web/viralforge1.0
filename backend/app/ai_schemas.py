"""Schemas the model must fill. Kept free of Field constraints/defaults so they convert cleanly
to Gemini's response schema; ranges and completeness are enforced by the validators below."""
from typing import Literal

from pydantic import BaseModel, field_validator, model_validator

from app.services.scoring import DIMENSION_KEYS

DimensionKey = Literal[
    "hook_strength", "clarity", "emotional_appeal", "entertainment_value",
    "information_value", "audience_retention", "shareability",
]
ObservationArea = Literal["visual_storytelling", "pacing", "opening_hook", "audio_speech", "on_screen_text"]
ModerationCategory = Literal[
    "sexual_content", "sexual_content_involving_minors", "graphic_violence", "violent_extremism",
    "hate_or_harassment", "self_harm_promotion", "illegal_activity", "dangerous_weapons_or_drugs",
    "fraud_or_scam", "privacy_violation", "other",
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
            raise ValueError("dimensions must contain each of the seven dimension keys exactly once")
        for name in ("strengths", "weaknesses", "recommendations"):
            if not 1 <= len(getattr(self, name)) <= 10:
                raise ValueError(f"{name} must contain 1 to 10 items")
        if not self.content_summary.strip():
            raise ValueError("content_summary must not be empty")
        return self


class PersonaReaction(BaseModel):
    persona_id: str
    first_impression: str
    interest_level: int
    likely_action: Literal["share", "like", "comment", "follow", "keep_scrolling"]
    would_finish: bool
    reaction: str
    concern: str

    @field_validator("interest_level")
    @classmethod
    def _i(cls, v: int) -> int:
        return _in_range(v, 1, 10, "interest_level")


class PersonaSimulation(BaseModel):
    reactions: list[PersonaReaction]


class ModerationVerdict(BaseModel):
    allowed: bool
    categories: list[ModerationCategory]
    reason: str

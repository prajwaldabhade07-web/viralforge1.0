"""Deterministic scoring. The model only rates seven dimensions (integers 1-10); every
derived and overall score is computed here with explicit rounding. See docs/SCORING.md."""
from decimal import ROUND_HALF_UP, Decimal

DIMENSION_KEYS = (
    "hook_strength",
    "clarity",
    "emotional_appeal",
    "entertainment_value",
    "information_value",
    "audience_retention",
    "shareability",
)

DIMENSION_LABELS = {
    "hook_strength": "Hook strength",
    "clarity": "Clarity",
    "emotional_appeal": "Emotional appeal",
    "entertainment_value": "Entertainment value",
    "information_value": "Information value",
    "audience_retention": "Audience retention potential",
    "shareability": "Shareability",
}

DIMENSION_DEFINITIONS = {
    "hook_strength": "How effectively the first 1-3 seconds stop the scroll and promise a reason to keep watching.",
    "clarity": "How easily a first-time viewer understands the point, in both visuals and audio or text.",
    "emotional_appeal": "How strongly the content triggers feeling: curiosity, humour, awe, empathy, surprise.",
    "entertainment_value": "How enjoyable the video is moment to moment, independent of its information.",
    "information_value": "How much a viewer learns or gains that they can use or repeat.",
    "audience_retention": "How likely viewers are to reach the end: pacing, payoff, loop or rewatch value.",
    "shareability": "How likely a viewer is to send or repost it: relatability, identity signalling, usefulness to others.",
}

ENGAGEMENT_INPUTS = ("clarity", "emotional_appeal", "entertainment_value", "information_value")
OVERALL_WEIGHTS = {
    "hook": Decimal("0.30"),
    "engagement": Decimal("0.25"),
    "retention": Decimal("0.25"),
    "shareability": Decimal("0.20"),
}

DIMENSION_SCALE = (
    "1-2 very weak, 3-4 weak, 5-6 average for the platform, 7-8 strong, 9-10 exceptional. "
    "Use 9-10 rarely; most competent videos land between 4 and 8."
)
BANDS = ((90, "Exceptional"), (75, "Strong"), (60, "Promising"), (40, "Developing"), (0, "Needs rework"))

RUBRIC = {
    "dimension_scale": "1-10 (integers), assigned by the AI for each dimension",
    "report_scale": "0-100 (integers)",
    "dimensions": [
        {"key": k, "label": DIMENSION_LABELS[k], "definition": DIMENSION_DEFINITIONS[k]}
        for k in DIMENSION_KEYS
    ],
    "formulas": {
        "hook": "Hook strength x 10",
        "engagement": "Mean of clarity, emotional appeal, entertainment value and information value, x 10",
        "retention": "Audience retention potential x 10",
        "shareability": "Shareability x 10",
        "overall": "0.30 x Hook + 0.25 x Engagement + 0.25 x Retention + 0.20 x Shareability, "
        "computed from the displayed (rounded) scores",
    },
    "rounding": "Round half up to the nearest integer",
    "dimension_anchor": DIMENSION_SCALE,
    "bands": [{"min": lo, "label": label} for lo, label in BANDS],
}


class ScoringError(ValueError):
    pass


def _round(value: Decimal) -> int:
    return int(value.quantize(Decimal("1"), rounding=ROUND_HALF_UP))


def band_for(score: int) -> str:
    for lo, label in BANDS:
        if score >= lo:
            return label
    return BANDS[-1][1]


def compute_scores(dimensions: dict[str, int]) -> dict[str, int]:
    """Return {hook, engagement, retention, shareability, overall} as integers 0-100."""
    missing = [k for k in DIMENSION_KEYS if k not in dimensions]
    if missing:
        raise ScoringError(f"Missing dimensions: {', '.join(missing)}")
    for k in DIMENSION_KEYS:
        v = dimensions[k]
        if isinstance(v, bool) or not isinstance(v, int) or not 1 <= v <= 10:
            raise ScoringError(f"Dimension {k} must be an integer from 1 to 10, got {v!r}")

    d = {k: Decimal(dimensions[k]) for k in DIMENSION_KEYS}
    hook = _round(d["hook_strength"] * 10)
    engagement = _round(sum(d[k] for k in ENGAGEMENT_INPUTS) / Decimal(len(ENGAGEMENT_INPUTS)) * 10)
    retention = _round(d["audience_retention"] * 10)
    shareability = _round(d["shareability"] * 10)
    parts = {"hook": hook, "engagement": engagement, "retention": retention, "shareability": shareability}
    overall = _round(sum(OVERALL_WEIGHTS[k] * Decimal(v) for k, v in parts.items()))
    return {**parts, "overall": overall}

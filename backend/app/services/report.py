"""Assemble the final Viral Readiness Report from validated model output."""

from datetime import UTC, datetime

from app.services import personas as personas_mod
from app.services.scoring import DIMENSION_LABELS, RUBRIC, band_for, compute_scores

SCHEMA_VERSION = 1
DISCLAIMER = (
    "This report is an AI-generated estimate based only on the content you submitted. It cannot "
    "predict real-world performance: reach, retention and shares also depend on your audience, "
    "posting time, account history and platform algorithms. Scores are a structured opinion, not "
    "a forecast. Persona reactions are AI-simulated and are not audience research."
)
_MAX_TEXT = 700


def _clip(value, limit=_MAX_TEXT) -> str:
    return str(value or "").strip()[:limit]


def build_report(
    *,
    job: dict,
    analysis: dict,
    persona_items: list[dict],
    persona_status: str,
    persona_received: int,
    persona_note: str | None,
    model: str,
    now: datetime | None = None,
) -> dict:
    dims = {d["key"]: d for d in analysis["dimensions"]}
    scores = compute_scores({k: int(v["score"]) for k, v in dims.items()})
    ordered_dims = [
        {
            "key": k,
            "label": DIMENSION_LABELS[k],
            "score": int(dims[k]["score"]),
            "rationale": _clip(dims[k]["rationale"]),
        }
        for k in DIMENSION_LABELS
    ]
    recs = sorted(analysis["recommendations"], key=lambda r: int(r["priority"]))
    generated = (now or datetime.now(UTC)).isoformat()
    return {
        "schema_version": SCHEMA_VERSION,
        "input_type": job["input_type"],
        "platform": job["platform"],
        "niche": job["niche"],
        "target_audience": job["target_audience"],
        "scores": scores,
        "verdict": band_for(scores["overall"]),
        "scale": {"min": 0, "max": 100},
        "dimensions": ordered_dims,
        "rubric": RUBRIC,
        "content_summary": _clip(analysis["content_summary"], 1200),
        "strengths": [_clip(s) for s in analysis["strengths"]],
        "weaknesses": [_clip(s) for s in analysis["weaknesses"]],
        "recommendations": [
            {
                "priority": i + 1,
                "title": _clip(r["title"], 160),
                "detail": _clip(r["detail"]),
                "expected_impact": r["expected_impact"],
            }
            for i, r in enumerate(recs)
        ],
        "observations": [
            {
                "area": o["area"],
                "observation": _clip(o["observation"]),
                "evidence": _clip(o["evidence"], 300),
            }
            for o in analysis["observations"]
        ],
        "confidence": analysis["confidence"],
        "confidence_note": _clip(analysis["confidence_note"]),
        "personas": {
            "label": "AI-simulated reactions. Not real audience research.",
            "status": persona_status,
            "expected": len(personas_mod.PERSONAS),
            "received": persona_received,
            "note": persona_note,
            "items": persona_items,
        },
        "disclaimer": DISCLAIMER,
        "model": model,
        "generated_at": generated,
    }

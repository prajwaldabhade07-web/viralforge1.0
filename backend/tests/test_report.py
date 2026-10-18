from datetime import UTC, datetime

from app.services.personas import PERSONA_IDS, PERSONAS, merge_reactions
from app.services.report import build_report
from app.services.scoring import DIMENSION_KEYS


def reaction(pid):
    return {
        "persona_id": pid,
        "first_impression": "ok",
        "interest_level": 7,
        "likely_action": "like",
        "would_finish": True,
        "reaction": "Liked it.",
        "concern": "Slow middle.",
    }


def analysis(**over):
    base = {
        "content_summary": "A person demonstrates a recipe.",
        "dimensions": [{"key": k, "score": 6, "rationale": f"because {k}"} for k in DIMENSION_KEYS],
        "strengths": ["Clear"],
        "weaknesses": ["Slow open"],
        "recommendations": [
            {"priority": 3, "title": "C", "detail": "c", "expected_impact": "low"},
            {"priority": 1, "title": "A", "detail": "a", "expected_impact": "high"},
        ],
        "observations": [{"area": "pacing", "observation": "steady", "evidence": "0:05"}],
        "confidence": "medium",
        "confidence_note": "Short clip.",
    }
    return {**base, **over}


JOB = {
    "input_type": "video",
    "platform": "tiktok",
    "niche": "cooking",
    "target_audience": "students",
}


def test_ten_distinct_personas():
    assert len(PERSONAS) == 10 and len(set(PERSONA_IDS)) == 10
    assert len({p["description"] for p in PERSONAS}) == 10


def test_merge_complete_partial_failed():
    items, status, n = merge_reactions([reaction(p) for p in PERSONA_IDS])
    assert (status, n, len(items)) == ("complete", 10, 10)
    items, status, n = merge_reactions(
        [reaction(p) for p in PERSONA_IDS[:4]] + [reaction("unknown"), reaction(PERSONA_IDS[0])]
    )
    assert (status, n, len(items)) == ("partial", 4, 10)
    assert [i["status"] for i in items].count("missing") == 6
    items, status, n = merge_reactions([])
    assert (status, n, len(items)) == ("failed", 0, 10)


def test_report_scores_are_computed_by_backend_and_recs_reprioritised():
    items, status, n = merge_reactions([reaction(p) for p in PERSONA_IDS])
    r = build_report(
        job=JOB,
        analysis=analysis(),
        persona_items=items,
        persona_status=status,
        persona_received=n,
        persona_note=None,
        model="m",
        now=datetime(2026, 1, 1, tzinfo=UTC),
    )
    assert r["scores"] == {
        "hook": 60,
        "engagement": 60,
        "retention": 60,
        "shareability": 60,
        "overall": 60,
    }
    assert r["verdict"] == "Promising"
    assert [x["title"] for x in r["recommendations"]] == ["A", "C"]
    assert [x["priority"] for x in r["recommendations"]] == [1, 2]
    assert r["personas"]["status"] == "complete" and "AI-simulated" in r["personas"]["label"]
    assert "not audience research" in r["disclaimer"] and r["rubric"]["formulas"]["overall"]
    assert [d["key"] for d in r["dimensions"]] == list(DIMENSION_KEYS)


def test_model_cannot_inject_scores():
    a = analysis()
    a["scores"] = {"overall": 100}  # extra field from the model must be ignored
    items, status, n = merge_reactions([])
    r = build_report(
        job=JOB,
        analysis=a,
        persona_items=items,
        persona_status=status,
        persona_received=n,
        persona_note="Persona simulation failed.",
        model="m",
    )
    assert r["scores"]["overall"] == 60 and r["personas"]["status"] == "failed"

import json

import pytest
from pydantic import ValidationError

from app.ai_schemas import ContentAnalysis, ModerationVerdict, PersonaReaction
from tests.fakes import good_analysis


def test_valid_analysis_parses_from_json():
    parsed = ContentAnalysis.model_validate_json(json.dumps(good_analysis()))
    assert len(parsed.dimensions) == 7


@pytest.mark.parametrize("mutate", [
    lambda a: a["dimensions"][0].update(score=11),
    lambda a: a["dimensions"][0].update(score=0),
    lambda a: a["dimensions"][0].update(score=5.5),
    lambda a: a["dimensions"].pop(),
    lambda a: a["dimensions"].append(dict(a["dimensions"][0])),
    lambda a: a["dimensions"][0].update(key="virality"),
    lambda a: a.update(strengths=[]),
    lambda a: a.update(recommendations=[]),
    lambda a: a.update(content_summary="  "),
    lambda a: a.update(confidence="certain"),
    lambda a: a["observations"][0].update(area="smell"),
])
def test_invalid_analysis_rejected(mutate):
    data = good_analysis()
    mutate(data)
    with pytest.raises(ValidationError):
        ContentAnalysis(**data)


def test_persona_and_moderation_validation():
    base = dict(persona_id="busy_parent", first_impression="x", interest_level=5, likely_action="like",
                would_finish=True, reaction="x", concern="x")
    PersonaReaction(**base)
    for bad in ({"interest_level": 0}, {"interest_level": 11}, {"likely_action": "buy"}):
        with pytest.raises(ValidationError):
            PersonaReaction(**{**base, **bad})
    with pytest.raises(ValidationError):
        ModerationVerdict(allowed=False, categories=["not_a_category"], reason="x")

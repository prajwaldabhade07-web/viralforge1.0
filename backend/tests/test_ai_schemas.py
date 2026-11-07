import json

import pytest
from pydantic import ValidationError

from app.ai_schemas import ContentAnalysis, ModerationVerdict, PersonaReaction, PersonaSimulation
from tests.fakes import good_analysis


def test_valid_analysis_parses_from_json():
    parsed = ContentAnalysis.model_validate_json(json.dumps(good_analysis()))
    assert len(parsed.dimensions) == 7


@pytest.mark.parametrize(
    "mutate",
    [
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
    ],
)
def test_invalid_analysis_rejected(mutate):
    data = good_analysis()
    mutate(data)
    with pytest.raises(ValidationError):
        ContentAnalysis(**data)


def _reaction(**over):
    base = dict(
        persona_id="busy_parent",
        first_impression="x",
        interest_level=5,
        likely_action="like",
        would_finish=True,
        reaction="x",
        concern="x",
    )
    return {**base, **over}


def test_persona_reaction_repairs_small_slips_instead_of_failing():
    assert PersonaReaction(**_reaction(interest_level=0)).interest_level == 1
    assert PersonaReaction(**_reaction(interest_level=11)).interest_level == 10
    assert PersonaReaction(**_reaction(interest_level="7.0")).interest_level == 7
    assert PersonaReaction(**_reaction(likely_action="Would Share")).likely_action == "share"
    assert PersonaReaction(**_reaction(likely_action="buy")).likely_action == "keep_scrolling"
    r = PersonaReaction(**_reaction(concern=None, first_impression=None, would_finish=None))
    assert (r.concern, r.first_impression, r.would_finish) == ("", "", False)
    with pytest.raises(ValidationError):
        PersonaReaction(**_reaction(interest_level="lots"))


def test_persona_simulation_drops_unusable_reactions_but_keeps_the_rest():
    data = {
        "reactions": [_reaction(persona_id="a"), {"persona_id": "b"}, _reaction(persona_id="c")]
    }
    sim = PersonaSimulation.model_validate_json(json.dumps(data))
    assert [r.persona_id for r in sim.reactions] == ["a", "c"]
    with pytest.raises(ValidationError):
        PersonaSimulation.model_validate_json(json.dumps({"reactions": [{"persona_id": "b"}]}))
    with pytest.raises(ValidationError):
        PersonaSimulation.model_validate_json(json.dumps({"reactions": []}))


def test_moderation_verdict_is_forgiving_but_still_decides():
    v = ModerationVerdict.model_validate_json(
        '{"allowed": "false", "categories": ["Graphic Violence", "weird", "weird"], "reason": null}'
    )
    assert v.allowed is False and v.categories == ["graphic_violence", "other"] and v.reason == ""
    v = ModerationVerdict.model_validate_json(
        '{"allowed": true, "categories": null, "reason": "OK"}'
    )
    assert v.allowed is True and v.categories == []
    with pytest.raises(ValidationError):
        ModerationVerdict.model_validate_json('{"categories": [], "reason": "x"}')

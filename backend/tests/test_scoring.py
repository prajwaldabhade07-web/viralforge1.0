import pytest

from app.services.scoring import ScoringError, band_for, compute_scores

ALL_FIVE = {
    k: 5
    for k in (
        "hook_strength",
        "clarity",
        "emotional_appeal",
        "entertainment_value",
        "information_value",
        "audience_retention",
        "shareability",
    )
}


def dims(**over):
    return {**ALL_FIVE, **over}


def test_uniform_scores():
    assert compute_scores(ALL_FIVE) == {
        "hook": 50,
        "engagement": 50,
        "retention": 50,
        "shareability": 50,
        "overall": 50,
    }


def test_engagement_is_mean_of_four_inputs():
    s = compute_scores(
        dims(clarity=10, emotional_appeal=8, entertainment_value=6, information_value=4)
    )
    assert s["engagement"] == 70  # mean 7.0 x 10


def test_round_half_up_not_bankers():
    # mean 7.25 -> 72.5 -> 73 (banker's rounding would give 72)
    s = compute_scores(
        dims(clarity=7, emotional_appeal=7, entertainment_value=7, information_value=8)
    )
    assert s["engagement"] == 73
    # mean 6.25 -> 62.5 -> 63
    s = compute_scores(
        dims(clarity=6, emotional_appeal=6, entertainment_value=6, information_value=7)
    )
    assert s["engagement"] == 63


def test_overall_uses_displayed_scores_and_weights():
    s = compute_scores(
        dims(
            hook_strength=9,
            clarity=8,
            emotional_appeal=8,
            entertainment_value=8,
            information_value=8,
            audience_retention=7,
            shareability=6,
        )
    )
    assert (s["hook"], s["engagement"], s["retention"], s["shareability"]) == (90, 80, 70, 60)
    # 0.30*90 + 0.25*80 + 0.25*70 + 0.20*60 = 76.5 -> 77 (half up; builtin round() would give 76)
    assert s["overall"] == 77


def test_extremes():
    assert compute_scores({k: 10 for k in ALL_FIVE})["overall"] == 100
    assert compute_scores({k: 1 for k in ALL_FIVE})["overall"] == 10


@pytest.mark.parametrize("bad", [0, 11, -3, 5.5, "7", None, True])
def test_rejects_invalid_dimension_values(bad):
    with pytest.raises(ScoringError):
        compute_scores(dims(clarity=bad))


def test_rejects_missing_dimension():
    d = dict(ALL_FIVE)
    d.pop("shareability")
    with pytest.raises(ScoringError):
        compute_scores(d)


@pytest.mark.parametrize(
    "score,label",
    [
        (0, "Needs rework"),
        (39, "Needs rework"),
        (40, "Developing"),
        (59, "Developing"),
        (60, "Promising"),
        (74, "Promising"),
        (75, "Strong"),
        (89, "Strong"),
        (90, "Exceptional"),
        (100, "Exceptional"),
    ],
)
def test_bands(score, label):
    assert band_for(score) == label

"""Ten fixed, deliberately different audience personas. Reactions are AI-simulated."""

PERSONAS = [
    {
        "id": "gen_z_scroller",
        "name": "Maya, the fast scroller",
        "description": "19, trend-fluent, decides in under two seconds whether to keep watching.",
    },
    {
        "id": "busy_parent",
        "name": "Daniel, the busy parent",
        "description": "38, watches in short gaps, wants something useful or genuinely funny, not filler.",
    },
    {
        "id": "niche_enthusiast",
        "name": "Priya, the niche enthusiast",
        "description": "27, deeply into this topic and quick to spot shallow or inaccurate content.",
    },
    {
        "id": "skeptical_critic",
        "name": "Tom, the sceptic",
        "description": "34, distrusts hype and clickbait, rewards honesty and substance.",
    },
    {
        "id": "sound_off_commuter",
        "name": "Lena, the sound-off commuter",
        "description": "29, watches on transit with audio off and relies on visuals and on-screen text.",
    },
    {
        "id": "small_business_owner",
        "name": "Carlos, the small business owner",
        "description": "42, watches for ideas he can apply to his own work and judges everything by usefulness.",
    },
    {
        "id": "college_student",
        "name": "Aisha, the college student",
        "description": "21, humour-driven, shares things with her group chat when they are relatable.",
    },
    {
        "id": "older_viewer",
        "name": "Harold, the 60+ viewer",
        "description": "63, prefers calm pacing, clear speech and readable text over rapid cuts.",
    },
    {
        "id": "aspiring_creator",
        "name": "Jordan, the aspiring creator",
        "description": "24, studies editing, hooks and pacing, and may remix ideas that work.",
    },
    {
        "id": "global_viewer",
        "name": "Mei, the non-native-English viewer",
        "description": "31, follows through visuals and captions and gets lost in fast slang or idioms.",
    },
]
PERSONA_IDS = [p["id"] for p in PERSONAS]
_BY_ID = {p["id"]: p for p in PERSONAS}


def merge_reactions(reactions: list[dict]) -> tuple[list[dict], str, int]:
    """Align model reactions to the ten fixed personas.

    Returns (items, status, received). Every persona appears once; personas with no valid
    reaction are listed as status "missing" so incomplete results are never hidden.
    status is "complete" (10), "partial" (1-9) or "failed" (0).
    """
    found: dict[str, dict] = {}
    for r in reactions or []:
        pid = r.get("persona_id")
        if pid in _BY_ID and pid not in found:
            found[pid] = r
    items = []
    for p in PERSONAS:
        base = {"persona_id": p["id"], "name": p["name"], "description": p["description"]}
        r = found.get(p["id"])
        if r is None:
            items.append({**base, "status": "missing"})
        else:
            items.append(
                {
                    **base,
                    "status": "ok",
                    "first_impression": r["first_impression"],
                    "interest_level": r["interest_level"],
                    "likely_action": r["likely_action"],
                    "would_finish": r["would_finish"],
                    "reaction": r["reaction"],
                    "concern": r["concern"],
                }
            )
    received = len(found)
    status = "complete" if received == len(PERSONAS) else ("partial" if received else "failed")
    return items, status, received


def failed_items() -> list[dict]:
    return merge_reactions([])[0]

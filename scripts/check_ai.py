r"""Checks the AI side of ViralForge against the real Gemini API. No Supabase needed.

Run from the repo root (Windows):
  backend\.venv\Scripts\python.exe scripts\check_ai.py                 text only: safety check + personas
  backend\.venv\Scripts\python.exe scripts\check_ai.py path\to\clip.mp4   full run: upload, safety, analysis,
                                                                          scores, personas
Each step prints OK or FAILED with the real reason, so you can see exactly which part has a problem.
API keys are never printed. Exit code 0 = everything worked."""

import mimetypes
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "backend"))

from app.ai_schemas import ContentAnalysis, ModerationVerdict, PersonaSimulation  # noqa: E402
from app.config import get_settings  # noqa: E402
from app.services import prompts  # noqa: E402
from app.services.gemini import GoogleGenaiGateway  # noqa: E402
from app.services.personas import merge_reactions  # noqa: E402
from app.services.scoring import compute_scores  # noqa: E402

failures = 0


def step(label, fn):
    """Run one step; print the outcome; return its result (None when it failed)."""
    global failures
    start = time.monotonic()
    try:
        result = fn()
        print(f"[ OK ] {label} ({time.monotonic() - start:.1f}s)")
        return result
    except Exception as e:  # noqa: BLE001
        failures += 1
        code = getattr(e, "code", "")
        print(f"[FAIL] {label}: {type(e).__name__} {code} {str(e)[:400]}")
        return None


def main() -> int:
    s = get_settings()
    if not s.gemini_api_key:
        print("GEMINI_API_KEY is empty in .env")
        return 1
    video = Path(sys.argv[1]) if len(sys.argv) > 1 else None
    if video and not video.is_file():
        print(f"Video not found: {video}")
        return 1
    print(f"Model: {s.gemini_model}  (parallel moderation: {s.parallel_moderation})")
    g = GoogleGenaiGateway(
        s.gemini_api_key,
        s.gemini_model,
        timeout_s=s.gemini_timeout_seconds,
        file_ready_timeout_s=s.gemini_file_ready_timeout_seconds,
        thinking_level=s.gemini_thinking_level,
        media_resolution=s.gemini_media_resolution,
    )
    ctx = {
        "platform": "tiktok",
        "niche": "home cooking",
        "target_audience": "busy students",
        "caption": "",
        "input_type": "video" if video else "script",
        "script_text": "Scene 1: a hand drops an egg into hot water and says 'stop boiling eggs wrong'. "
        "Scene 2: a quick peel test. Scene 3: text on screen shows the 6 minute timer.",
    }
    if not step("Model available for this key", g.check_model) and failures:
        return 1

    handle = None
    mime = None
    if video:
        mime = mimetypes.guess_type(video.name)[0] or "video/mp4"
        handle = step("Upload video to Gemini", lambda: g.upload_video(str(video), mime))
        if handle is None:
            return 1
    try:
        verdict = step(
            "Safety check (moderation)",
            lambda: g.generate_json(
                system=prompts.MODERATION_SYSTEM,
                prompt=prompts.moderation_prompt(ctx),
                schema=ModerationVerdict,
                file=handle,
                temperature=0.0,
            ),
        )
        if verdict is not None:
            print(f"       allowed={verdict.allowed} categories={verdict.categories}")
        analysis = None
        if video:
            analysis = step(
                "Video analysis",
                lambda: g.generate_json(
                    system=prompts.ANALYSIS_SYSTEM,
                    prompt=prompts.analysis_prompt(ctx),
                    schema=ContentAnalysis,
                    file=handle,
                    temperature=0.3,
                ),
            )
            if analysis is not None:
                scores = compute_scores({d.key: d.score for d in analysis.dimensions})
                print(f"       scores: {scores}")
        if analysis is not None:
            adict = analysis.model_dump()
        else:
            adict = {
                "content_summary": "A quick kitchen tip: a cook shows the right way to boil eggs and "
                "peel them, with a 6 minute timer shown on screen.",
                "dimensions": [{"key": "hook_strength", "score": 6}],
            }
        sim = step(
            "Ten persona reactions",
            lambda: g.generate_json(
                system=prompts.PERSONA_SYSTEM,
                prompt=prompts.persona_prompt(ctx, adict["content_summary"], adict),
                schema=PersonaSimulation,
                temperature=0.7,
            ),
        )
        if sim is not None:
            _, status, received = merge_reactions([r.model_dump() for r in sim.reactions])
            print(f"       personas: {received}/10 ({status})")
    finally:
        if handle is not None:
            g.delete_file(handle)
    print("\nAll AI steps worked." if failures == 0 else f"\n{failures} step(s) failed. See above.")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    sys.exit(main())

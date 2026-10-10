"""Analysis job processing: validate -> moderate (fail closed) -> analyse -> personas -> report.

State changes are guarded with `status = 'processing'` so a worker that lost its lease cannot
overwrite a job another worker finished or that was recovered.
"""
import logging
import os
import tempfile
from datetime import datetime, timedelta, timezone

from app.ai_schemas import ContentAnalysis, ModerationVerdict, PersonaSimulation
from app.config import Settings
from app.errors import UniqueViolation
from app.repo import Repo
from app.services import prompts
from app.services.gemini import (
    FileProcessingError,
    GeminiGateway,
    MalformedResponse,
    ModelUnavailable,
    ProviderError,
)
from app.services.personas import failed_items, merge_reactions
from app.services.report import build_report
from app.services.safety import detect_injection, sanitize_text
from app.storage import Storage

log = logging.getLogger("viralforge.pipeline")

CATEGORY_LABELS = {
    "sexual_content": "sexual content", "sexual_content_involving_minors": "content involving minors",
    "graphic_violence": "graphic violence", "violent_extremism": "violent extremism",
    "hate_or_harassment": "hate or harassment", "self_harm_promotion": "self-harm promotion",
    "illegal_activity": "illegal activity", "dangerous_weapons_or_drugs": "weapons or drugs",
    "fraud_or_scam": "fraud or scams", "privacy_violation": "privacy violation", "other": "policy violation",
}


class PipelineError(Exception):
    def __init__(self, code: str, message: str, *, transient: bool = False):
        super().__init__(message)
        self.code, self.message, self.transient = code, message, transient


class LeaseLost(Exception):
    pass


class AnalysisPipeline:
    def __init__(self, settings: Settings, repo: Repo, storage: Storage, gemini: GeminiGateway):
        self.s, self.repo, self.storage, self.gemini = settings, repo, storage, gemini

    # ---- public ---------------------------------------------------------------------------
    def process(self, job: dict) -> None:
        jid = job["id"]
        tmp_path, gfile = None, None
        try:
            ctx = self._prepare(job)
            mime = None
            if job["input_type"] == "video":
                self._progress(job, "preparing_video", 10)
                tmp_path, mime = self._fetch_video(job)
                self._progress(job, "uploading", 25)
                gfile = self._call(lambda: self.gemini.upload_video(tmp_path, mime))

            self._progress(job, "moderating", 35)
            verdict = self._call(
                lambda: self.gemini.generate_json(
                    system=prompts.MODERATION_SYSTEM, prompt=prompts.moderation_prompt(ctx),
                    schema=ModerationVerdict, file=gfile, temperature=0.0),
                stage="moderation")
            if not verdict.allowed:
                self._block(job, verdict)
                return

            self._progress(job, "analyzing", 50)
            analysis = self._call(
                lambda: self.gemini.generate_json(
                    system=prompts.ANALYSIS_SYSTEM, prompt=prompts.analysis_prompt(ctx),
                    schema=ContentAnalysis, file=gfile, temperature=0.3))
            adict = analysis.model_dump()

            self._progress(job, "simulating_audience", 80)
            items, pstatus, received, note = self._personas(ctx, adict)

            self._progress(job, "finalizing", 95)
            report = build_report(job=ctx, analysis=adict, persona_items=items, persona_status=pstatus,
                                  persona_received=received, persona_note=note, model=self.s.gemini_model)
            self._complete(job, report)
        except LeaseLost:
            log.warning("Job %s lost its lease; abandoning this run", jid)
        except PipelineError as e:
            self._fail(job, e)
        except Exception:  # noqa: BLE001
            log.exception("Unexpected error processing job %s", jid)  # no user content is logged
            self._fail(job, PipelineError("internal_error", "Something went wrong while analysing. Retry the analysis."))
        finally:
            if gfile is not None:
                self.gemini.delete_file(gfile)
            if tmp_path and os.path.exists(tmp_path):
                os.remove(tmp_path)

    # ---- steps ----------------------------------------------------------------------------
    def _prepare(self, job: dict) -> dict:
        ctx = dict(job)
        ctx["niche"] = sanitize_text(job.get("niche"), 100)
        ctx["target_audience"] = sanitize_text(job.get("target_audience"), 200)
        ctx["caption"] = sanitize_text(job.get("caption"), 2200)
        ctx["script_text"] = sanitize_text(job.get("script_text"), 8000)
        if any(detect_injection(ctx[k]) for k in ("niche", "target_audience", "caption", "script_text")):
            log.warning("Possible prompt-injection text in job %s (content not logged)", job["id"])
        if job["input_type"] == "script" and not ctx["script_text"]:
            raise PipelineError("invalid_input", "The script text is empty.")
        return ctx

    def _fetch_video(self, job: dict) -> tuple[str, str]:
        rows = self.repo.select("videos", {"id": job.get("video_id"), "user_id": job["user_id"]}, limit=1) \
            if job.get("video_id") else []
        if not rows:
            raise PipelineError("video_missing", "The video was deleted before the analysis could run.")
        video = rows[0]
        try:
            data = self.storage.download(video["storage_path"])
        except Exception as e:  # noqa: BLE001
            raise PipelineError("storage_unavailable", "Could not read the stored video. Retry shortly.", transient=True) from e
        fd, path = tempfile.mkstemp(suffix="." + video["storage_path"].rsplit(".", 1)[-1])
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        return path, video["mime_type"]

    def _call(self, fn, stage: str = "analysis"):
        try:
            return fn()
        except ModelUnavailable as e:
            raise PipelineError("model_unavailable", str(e)) from e
        except FileProcessingError as e:
            raise PipelineError("video_unprocessable", str(e)) from e
        except ProviderError as e:
            if stage == "moderation":
                raise PipelineError("moderation_unavailable",
                                    "The safety check could not be completed, so nothing was analysed. Retry in a moment.",
                                    transient=e.transient) from e
            raise PipelineError("ai_service_unavailable", str(e), transient=e.transient) from e
        except MalformedResponse as e:
            if stage == "moderation":
                raise PipelineError("moderation_unavailable",
                                    "The safety check could not be completed, so nothing was analysed. Retry in a moment.") from e
            raise PipelineError("ai_response_invalid",
                                "The AI returned a response that could not be used. Retry the analysis.") from e

    def _personas(self, ctx: dict, adict: dict):
        summary = adict["content_summary"]
        try:
            sim = self._call(lambda: self.gemini.generate_json(
                system=prompts.PERSONA_SYSTEM, prompt=prompts.persona_prompt(ctx, summary, adict),
                schema=PersonaSimulation, temperature=0.8), stage="personas")
            reactions = [r.model_dump() for r in sim.reactions]
            items, status, received = merge_reactions(reactions)
            if status == "partial":
                missing = [i["persona_id"] for i in items if i["status"] == "missing"]
                try:
                    more = self._call(lambda: self.gemini.generate_json(
                        system=prompts.PERSONA_SYSTEM,
                        prompt=prompts.persona_prompt(ctx, summary, adict, only_ids=missing),
                        schema=PersonaSimulation, temperature=0.8), stage="personas")
                    items, status, received = merge_reactions(reactions + [r.model_dump() for r in more.reactions])
                except PipelineError:
                    pass
            note = None if status == "complete" else (
                f"Only {received} of 10 persona reactions could be produced. Missing personas are marked; "
                "the rest of the report is unaffected.")
            return items, status, received, note
        except PipelineError as e:
            return failed_items(), "failed", 0, f"Persona simulation failed ({e.message}) The rest of the report is unaffected."

    # ---- state transitions ------------------------------------------------------------------
    def _now(self) -> datetime:
        return datetime.now(timezone.utc)

    def _guarded(self, job: dict, patch: dict) -> None:
        rows = self.repo.update("analysis_jobs", {"id": job["id"], "status": "processing"}, patch)
        if not rows:
            raise LeaseLost()

    def _progress(self, job: dict, stage: str, progress: int) -> None:
        self._guarded(job, {"stage": stage, "progress": progress, "locked_at": self._now().isoformat()})

    def _complete(self, job: dict, report: dict) -> None:
        row = {"job_id": job["id"], "user_id": job["user_id"], "project_id": job["project_id"],
               "scores": report["scores"], "report": report, "model": report["model"]}
        try:
            self.repo.insert("reports", row)
        except UniqueViolation:
            self.repo.delete("reports", {"job_id": job["id"]})
            self.repo.insert("reports", row)
        self._guarded(job, {"status": "completed", "stage": "completed", "progress": 100, "locked_at": None,
                            "error_code": None, "error_message": None, "completed_at": self._now().isoformat()})

    def _fail(self, job: dict, err: PipelineError) -> None:
        now = self._now()
        attempts = int(job.get("attempts") or 1)
        try:
            if err.transient and attempts < int(job.get("max_attempts") or self.s.max_job_attempts):
                delay = 20 * attempts
                self._guarded(job, {"status": "queued", "stage": "retrying", "progress": 0, "locked_at": None,
                                    "run_after": (now + timedelta(seconds=delay)).isoformat()})
                log.info("Job %s requeued after transient error %s", job["id"], err.code)
            else:
                self._guarded(job, {"status": "failed", "stage": "failed", "locked_at": None,
                                    "error_code": err.code, "error_message": err.message,
                                    "completed_at": now.isoformat()})
                log.info("Job %s failed: %s", job["id"], err.code)
        except LeaseLost:
            log.warning("Job %s lost its lease while recording failure", job["id"])

    def _block(self, job: dict, verdict: ModerationVerdict) -> None:
        cats = ", ".join(CATEGORY_LABELS.get(c, c) for c in verdict.categories) or "content policy"
        if job.get("video_id"):
            rows = self.repo.select("videos", {"id": job["video_id"], "user_id": job["user_id"]}, limit=1)
            for v in rows:
                try:
                    self.storage.remove([v["storage_path"]])
                except Exception:  # noqa: BLE001
                    log.warning("Could not remove blocked video object for job %s", job["id"])
                self.repo.delete("videos", {"id": v["id"], "user_id": job["user_id"]})
        self._guarded(job, {
            "status": "failed", "stage": "blocked", "locked_at": None, "video_id": None,
            "caption": None, "script_text": None,  # blocked submissions are not retained
            "error_code": "content_blocked",
            "error_message": f"This submission was blocked by the content policy ({cats}). It was not analysed "
                             "and the uploaded video was deleted.",
            "completed_at": self._now().isoformat()})
        log.info("Job %s blocked by moderation (%s)", job["id"], cats)

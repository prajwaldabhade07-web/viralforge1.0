"""In-memory stand-ins for Supabase, Gemini and auth so tests need no network or credits."""
import copy
import uuid
from datetime import datetime, timezone
from types import SimpleNamespace

from app.ai_schemas import ContentAnalysis, ModerationVerdict, PersonaReaction, PersonaSimulation
from app.auth import CurrentUser
from app.config import Settings
from app.container import Container
from app.errors import AppError, UniqueViolation
from app.services.gemini import ModelUnavailable
from app.services.personas import PERSONA_IDS
from app.services.scoring import DIMENSION_KEYS

ACTIVE = ("queued", "processing")


def now_iso():
    return datetime.now(timezone.utc).isoformat()


class InMemoryRepo:
    def __init__(self):
        self.tables: dict[str, list[dict]] = {"projects": [], "videos": [], "analysis_jobs": [], "reports": []}

    # -- helpers
    @staticmethod
    def _match(row, where):
        for k, v in (where or {}).items():
            if isinstance(v, tuple) and v and v[0] == "in":
                if row.get(k) not in v[1]:
                    return False
            elif row.get(k) != v:
                return False
        return True

    def _check_unique(self, table, row, ignore_id=None):
        rows = [r for r in self.tables[table] if r["id"] != ignore_id]
        if table == "analysis_jobs" and row.get("video_id") and row.get("status") in ACTIVE:
            if any(r.get("video_id") == row["video_id"] and r["status"] in ACTIVE for r in rows):
                raise UniqueViolation(table)
        if table == "videos" and any(r["storage_path"] == row["storage_path"] for r in rows):
            raise UniqueViolation(table)
        if table == "reports" and any(r["job_id"] == row["job_id"] for r in rows):
            raise UniqueViolation(table)

    # -- Repo interface
    def insert(self, table, row):
        row = copy.deepcopy(row)
        row.setdefault("id", str(uuid.uuid4()))
        ts = now_iso()
        row.setdefault("created_at", ts)
        if table in ("projects", "analysis_jobs"):
            row.setdefault("updated_at", ts)
        if table == "analysis_jobs":
            for k, v in {"run_after": ts, "locked_at": None, "started_at": None, "completed_at": None,
                         "error_code": None, "error_message": None, "attempts": 0}.items():
                row.setdefault(k, v)
        if table == "projects":
            for k in ("description", "platform", "niche", "target_audience"):
                row.setdefault(k, None)
        self._check_unique(table, row)
        self.tables[table].append(row)
        return copy.deepcopy(row)

    def select(self, table, where=None, order=None, desc=True, limit=None, offset=0):
        rows = [r for r in self.tables[table] if self._match(r, where)]
        if order:
            rows.sort(key=lambda r: (r.get(order) is None, r.get(order)), reverse=desc)
        if limit is not None:
            rows = rows[offset:offset + limit]
        return copy.deepcopy(rows)

    def count(self, table, where=None):
        return sum(1 for r in self.tables[table] if self._match(r, where))

    def update(self, table, where, patch):
        out = []
        for r in self.tables[table]:
            if self._match(r, where):
                candidate = {**r, **patch}
                self._check_unique(table, candidate, ignore_id=r["id"])
                r.update(copy.deepcopy(patch))
                r["updated_at"] = now_iso() if "updated_at" in r else r.get("updated_at")
                out.append(copy.deepcopy(r))
        return out

    def delete(self, table, where):
        victims = [r for r in self.tables[table] if self._match(r, where)]
        for r in victims:
            self.tables[table].remove(r)
            if table == "projects":
                for t in ("videos", "analysis_jobs", "reports"):
                    self.tables[t] = [x for x in self.tables[t] if x["project_id"] != r["id"]]
            if table == "videos":
                for j in self.tables["analysis_jobs"]:
                    if j.get("video_id") == r["id"]:
                        j["video_id"] = None
            if table == "analysis_jobs":
                self.tables["reports"] = [x for x in self.tables["reports"] if x["job_id"] != r["id"]]
        return len(victims)

    def claim_next_job(self, lease_seconds):
        """Python port of the SQL claim_next_job() semantics."""
        now = datetime.now(timezone.utc)
        parse = datetime.fromisoformat
        stale = lambda j: j["status"] == "processing" and j["locked_at"] and \
            (now - parse(j["locked_at"])).total_seconds() > lease_seconds
        for j in self.tables["analysis_jobs"]:
            if stale(j) and j["attempts"] >= j["max_attempts"]:
                j.update(status="failed", stage="failed", locked_at=None, completed_at=now_iso(),
                         error_code="worker_timeout", error_message="The analysis stopped unexpectedly. Retry the analysis.")
        runnable = [j for j in self.tables["analysis_jobs"]
                    if (j["status"] == "queued" and parse(j["run_after"]) <= now) or stale(j)]
        if not runnable:
            return None
        j = sorted(runnable, key=lambda x: x["created_at"])[0]
        j.update(status="processing", stage="validating", progress=5, attempts=j["attempts"] + 1,
                 locked_at=now_iso(), started_at=j["started_at"] or now_iso(), error_code=None, error_message=None)
        return copy.deepcopy(j)


class InMemoryStorage:
    def __init__(self):
        self.objects: dict[str, tuple[bytes, str]] = {}

    def upload(self, path, data, content_type):
        if path in self.objects:
            raise RuntimeError("exists")
        self.objects[path] = (data, content_type)

    def download(self, path):
        return self.objects[path][0]

    def signed_url(self, path, ttl_seconds):
        if path not in self.objects:
            raise RuntimeError("missing")
        return f"https://storage.test/sign/{path}?token=t&ttl={ttl_seconds}"

    def remove(self, paths):
        for p in paths:
            self.objects.pop(p, None)


class FakeAuth:
    USERS = {"token-alice": CurrentUser("11111111-1111-1111-1111-111111111111", "alice@example.com"),
             "token-bob": CurrentUser("22222222-2222-2222-2222-222222222222", "bob@example.com")}

    def verify(self, token):
        if token not in self.USERS:
            raise AppError(401, "invalid_token", "Your session is invalid or has expired. Sign in again.")
        return self.USERS[token]


def good_analysis() -> dict:
    return {
        "content_summary": "A creator shows a 3-step budget meal prep. Fast cuts, text overlays, upbeat music.",
        "dimensions": [{"key": k, "score": s, "rationale": f"Rationale for {k}."}
                       for k, s in zip(DIMENSION_KEYS, (8, 7, 6, 7, 8, 6, 5))],
        "strengths": ["Strong first second", "Clear steps"],
        "weaknesses": ["Ending lacks a call to action"],
        "recommendations": [
            {"priority": 2, "title": "Add a payoff", "detail": "Show the finished meal at the end.", "expected_impact": "medium"},
            {"priority": 1, "title": "Tighten the middle", "detail": "Cut seconds 12-18.", "expected_impact": "high"}],
        "observations": [{"area": "opening_hook", "observation": "Opens on the finished dish.", "evidence": "0:00-0:02"}],
        "confidence": "high", "confidence_note": "Clear audio and visuals.",
    }


def reaction(pid) -> PersonaReaction:
    return PersonaReaction(persona_id=pid, first_impression="Catchy.", interest_level=7, likely_action="like",
                           would_finish=True, reaction="Would watch to the end.", concern="Some jargon.")


class FakeGemini:
    """Scripted Gemini. `errors[SchemaName]` may hold an exception or a list consumed in order."""

    def __init__(self):
        self.calls: list[str] = []
        self.prompts: list[str] = []
        self.files_used: list = []
        self.uploads: list[str] = []
        self.deleted: list[str] = []
        self.model_ok = True
        self.verdict = ModerationVerdict(allowed=True, categories=[], reason="OK")
        self.analysis = good_analysis()
        self.persona_batches: list[list[str]] = [list(PERSONA_IDS)]
        self.errors: dict[str, object] = {}
        self.on_call = None  # optional hook(schema_name) for concurrency simulations

    def check_model(self):
        if not self.model_ok:
            raise ModelUnavailable("Model 'gemini-x' is not available for this API key.")

    def upload_video(self, path, mime_type):
        self.uploads.append(path)
        return SimpleNamespace(name="files/test123")

    def delete_file(self, handle):
        self.deleted.append(handle.name)

    def generate_json(self, *, system, prompt, schema, file=None, temperature=0.3):
        name = schema.__name__
        self.calls.append(name)
        self.prompts.append(prompt)
        self.files_used.append(file)
        if self.on_call:
            self.on_call(name)
        err = self.errors.get(name)
        if isinstance(err, list):
            err = err.pop(0) if err else None
        if err:
            raise err
        if schema is ModerationVerdict:
            return self.verdict
        if schema is ContentAnalysis:
            return ContentAnalysis(**self.analysis)
        ids = self.persona_batches.pop(0) if len(self.persona_batches) > 1 else self.persona_batches[0]
        return PersonaSimulation(reactions=[reaction(i) for i in ids])


def make_settings(**over) -> Settings:
    base = dict(supabase_url="http://supabase.test", supabase_service_role_key="service-test",
                gemini_api_key="gemini-test", gemini_model="gemini-test-model", worker_enabled=False,
                max_upload_mb=5, rate_limit_per_minute=1000)
    return Settings(_env_file=None, **{**base, **over})


def make_container(**over) -> Container:
    c = Container(settings=make_settings(**over), repo=InMemoryRepo(), storage=InMemoryStorage(),
                  auth=FakeAuth(), gemini=FakeGemini())
    c.refresh_model_status()
    return c

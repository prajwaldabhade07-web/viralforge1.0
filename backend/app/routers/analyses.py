from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query, Response

from app.auth import CurrentUser
from app.container import Container
from app.deps import current_user, get_container, owned_project
from app.errors import UniqueViolation, conflict, not_found
from app.schemas import AnalysisCreate, JobDetailOut, JobOut, JobPage, ReportOut
from app.serialize import ACTIVE, job_out

router = APIRouter(tags=["analyses"])


def owned_job(c: Container, user_id: str, job_id: str) -> dict:
    rows = c.repo.select("analysis_jobs", {"id": job_id, "user_id": user_id}, limit=1)
    if not rows:
        raise not_found("Analysis")
    return rows[0]


def _scores_by_job(c: Container, user_id: str, job_ids: list[str]) -> dict[str, dict]:
    if not job_ids:
        return {}
    rows = c.repo.select("reports", {"user_id": user_id, "job_id": ("in", job_ids)})
    return {r["job_id"]: r["scores"] for r in rows}


def _page(c: Container, user_id: str, where: dict, limit: int, offset: int) -> dict:
    jobs = c.repo.select("analysis_jobs", where, order="created_at", limit=limit, offset=offset)
    scores = _scores_by_job(c, user_id, [j["id"] for j in jobs])
    names: dict[str, str] = {}
    pids = list({j["project_id"] for j in jobs})
    if pids:
        names = {p["id"]: p["name"] for p in c.repo.select("projects", {"user_id": user_id, "id": ("in", pids)})}
    return {"items": [job_out(j, scores.get(j["id"]), names.get(j["project_id"])) for j in jobs],
            "total": c.repo.count("analysis_jobs", where), "limit": limit, "offset": offset}


@router.post("/projects/{project_id}/analyses", response_model=JobOut, status_code=202,
             summary="Start an analysis (returns immediately; poll the job)")
def create_analysis(project_id: str, body: AnalysisCreate, user: CurrentUser = Depends(current_user),
                    c: Container = Depends(get_container)):
    owned_project(c, user.id, project_id)
    c.limiter.hit("analysis", user.id, c.settings.analysis_limit_per_hour, 3600)
    c.require_model()

    if body.input_type == "video":
        vids = c.repo.select("videos", {"id": body.video_id, "user_id": user.id, "project_id": project_id}, limit=1)
        if not vids:
            raise not_found("Video")
        if c.repo.count("analysis_jobs", {"video_id": body.video_id, "status": ("in", list(ACTIVE))}):
            raise conflict("analysis_in_progress", "This video already has an analysis in progress.")
        if c.repo.count("analysis_jobs", {"video_id": body.video_id, "status": "completed"}):
            raise conflict("already_analyzed", "This video has already been analysed. Open its report from your history, "
                           "or upload the edited version as a new video.")
    row = {
        "user_id": user.id, "project_id": project_id, "input_type": body.input_type,
        "video_id": body.video_id if body.input_type == "video" else None,
        "script_text": body.script_text, "platform": body.platform, "niche": body.niche,
        "target_audience": body.target_audience, "caption": body.caption or None,
        "status": "queued", "stage": "queued", "progress": 0, "attempts": 0,
        "max_attempts": c.settings.max_job_attempts,
    }
    try:
        job = c.repo.insert("analysis_jobs", row)
    except UniqueViolation as e:  # race: two submissions at once (DB partial unique index)
        raise conflict("analysis_in_progress", "This video already has an analysis in progress.") from e
    return job_out(job)


@router.get("/projects/{project_id}/analyses", response_model=JobPage, summary="Analysis history for a project")
def project_history(project_id: str, limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
                    user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)):
    owned_project(c, user.id, project_id)
    return _page(c, user.id, {"project_id": project_id, "user_id": user.id}, limit, offset)


@router.get("/history", response_model=JobPage, summary="Analysis history across all your projects")
def history(limit: int = Query(20, ge=1, le=100), offset: int = Query(0, ge=0),
            user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)):
    return _page(c, user.id, {"user_id": user.id}, limit, offset)


@router.get("/analyses/{job_id}", response_model=JobDetailOut, summary="Job status (and report when completed)")
def get_analysis(job_id: str, user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)):
    job = owned_job(c, user.id, job_id)
    report = None
    scores = None
    if job["status"] == "completed":
        rows = c.repo.select("reports", {"job_id": job_id, "user_id": user.id}, limit=1)
        if rows:
            report, scores = rows[0]["report"], rows[0]["scores"]
    names = {p["id"]: p["name"] for p in c.repo.select("projects", {"id": job["project_id"], "user_id": user.id})}
    return {**job_out(job, scores, names.get(job["project_id"])), "report": report}


@router.get("/analyses/{job_id}/report", response_model=ReportOut, summary="Completed Viral Readiness Report")
def get_report(job_id: str, user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)):
    owned_job(c, user.id, job_id)
    rows = c.repo.select("reports", {"job_id": job_id, "user_id": user.id}, limit=1)
    if not rows:
        raise not_found("Report")
    return rows[0]


@router.post("/analyses/{job_id}/retry", response_model=JobOut, status_code=202, summary="Retry a failed analysis")
def retry_analysis(job_id: str, user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)):
    job = owned_job(c, user.id, job_id)
    if not job_out(job)["retryable"]:
        raise conflict("not_retryable", "This analysis cannot be retried. Start a new analysis instead.")
    c.require_model()
    patch = {"status": "queued", "stage": "queued", "progress": 0, "error_code": None, "error_message": None,
             "completed_at": None, "locked_at": None, "run_after": datetime.now(timezone.utc).isoformat()}
    try:
        rows = c.repo.update("analysis_jobs", {"id": job_id, "user_id": user.id, "status": "failed"}, patch)
    except UniqueViolation as e:
        raise conflict("analysis_in_progress", "This video already has an analysis in progress.") from e
    if not rows:  # lost a race with another retry
        raise conflict("not_retryable", "This analysis is no longer in a failed state.")
    return job_out(rows[0])


@router.delete("/analyses/{job_id}", status_code=204, summary="Delete an analysis and its report")
def delete_analysis(job_id: str, user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)):
    job = owned_job(c, user.id, job_id)
    if job["status"] in ACTIVE:
        raise conflict("analysis_in_progress", "This analysis is still running.")
    c.repo.delete("reports", {"job_id": job_id, "user_id": user.id})
    c.repo.delete("analysis_jobs", {"id": job_id, "user_id": user.id})
    return Response(status_code=204)

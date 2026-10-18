import logging

from fastapi import APIRouter, Depends, Query, Response

from app.auth import CurrentUser
from app.container import Container
from app.deps import current_user, get_container, owned_project
from app.errors import conflict
from app.schemas import ProjectCreate, ProjectOut, ProjectPage, ProjectUpdate
from app.serialize import ACTIVE

log = logging.getLogger("viralforge.projects")
router = APIRouter(prefix="/projects", tags=["projects"])


def _with_counts(c: Container, rows: list[dict]) -> list[dict]:
    if not rows:
        return []
    jobs = c.repo.select("analysis_jobs", {"project_id": ("in", [r["id"] for r in rows])})
    counts: dict[str, int] = {}
    for j in jobs:
        counts[j["project_id"]] = counts.get(j["project_id"], 0) + 1
    return [{**r, "analysis_count": counts.get(r["id"], 0)} for r in rows]


@router.post("", response_model=ProjectOut, status_code=201, summary="Create a project")
def create_project(
    body: ProjectCreate,
    user: CurrentUser = Depends(current_user),
    c: Container = Depends(get_container),
):
    row = c.repo.insert("projects", {**body.model_dump(), "user_id": user.id})
    return {**row, "analysis_count": 0}


@router.get("", response_model=ProjectPage, summary="List your projects (newest first)")
def list_projects(
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: CurrentUser = Depends(current_user),
    c: Container = Depends(get_container),
):
    where = {"user_id": user.id}
    rows = c.repo.select("projects", where, order="updated_at", limit=limit, offset=offset)
    return {
        "items": _with_counts(c, rows),
        "total": c.repo.count("projects", where),
        "limit": limit,
        "offset": offset,
    }


@router.get("/{project_id}", response_model=ProjectOut, summary="Get a project")
def get_project(
    project_id: str,
    user: CurrentUser = Depends(current_user),
    c: Container = Depends(get_container),
):
    return _with_counts(c, [owned_project(c, user.id, project_id)])[0]


@router.patch("/{project_id}", response_model=ProjectOut, summary="Edit a project")
def update_project(
    project_id: str,
    body: ProjectUpdate,
    user: CurrentUser = Depends(current_user),
    c: Container = Depends(get_container),
):
    owned_project(c, user.id, project_id)
    patch = body.model_dump(exclude_unset=True)
    if "name" in patch and not patch["name"]:
        patch.pop("name")
    rows = (
        c.repo.update("projects", {"id": project_id, "user_id": user.id}, patch)
        if patch
        else [owned_project(c, user.id, project_id)]
    )
    return _with_counts(c, rows)[0]


@router.delete(
    "/{project_id}", status_code=204, summary="Delete a project with its videos and reports"
)
def delete_project(
    project_id: str,
    user: CurrentUser = Depends(current_user),
    c: Container = Depends(get_container),
):
    owned_project(c, user.id, project_id)
    if c.repo.count(
        "analysis_jobs",
        {"project_id": project_id, "user_id": user.id, "status": ("in", list(ACTIVE))},
    ):
        raise conflict(
            "analysis_in_progress",
            "An analysis is still running in this project. Wait for it to finish.",
        )
    videos = c.repo.select("videos", {"project_id": project_id, "user_id": user.id})
    paths = [v["storage_path"] for v in videos]
    try:
        c.storage.remove(paths)
    except Exception:  # noqa: BLE001
        log.warning("Some stored files for project %s could not be removed", project_id)
    c.repo.delete(
        "projects", {"id": project_id, "user_id": user.id}
    )  # cascades to videos, jobs, reports
    return Response(status_code=204)

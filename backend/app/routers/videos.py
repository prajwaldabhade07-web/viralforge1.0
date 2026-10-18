import logging
import uuid

from fastapi import APIRouter, Depends, File, Query, Request, Response, UploadFile

from app.auth import CurrentUser
from app.container import Container
from app.deps import current_user, get_container, owned_project
from app.errors import AppError, conflict, not_found
from app.schemas import SignedUrlOut, VideoOut, VideoPage
from app.serialize import ACTIVE
from app.services.media import MediaError, validate_upload

log = logging.getLogger("viralforge.videos")
router = APIRouter(tags=["videos"])
_CHUNK = 1024 * 1024


def owned_video(c: Container, user_id: str, video_id: str) -> dict:
    rows = c.repo.select("videos", {"id": video_id, "user_id": user_id}, limit=1)
    if not rows:
        raise not_found("Video")
    return rows[0]


@router.post(
    "/projects/{project_id}/videos",
    response_model=VideoOut,
    status_code=201,
    summary="Upload a video to a project",
)
def upload_video(
    project_id: str,
    request: Request,
    file: UploadFile = File(...),
    user: CurrentUser = Depends(current_user),
    c: Container = Depends(get_container),
):
    s = c.settings
    c.limiter.hit("upload", user.id, s.upload_limit_per_hour, 3600)
    owned_project(c, user.id, project_id)

    declared = request.headers.get("content-length")
    if declared and declared.isdigit() and int(declared) > s.max_upload_bytes + 1024 * 1024:
        raise AppError(413, "file_too_large", f"The video is larger than {s.max_upload_mb} MB.")

    buf = bytearray()
    while True:  # bounded read: stop as soon as the limit is exceeded
        chunk = file.file.read(_CHUNK)
        if not chunk:
            break
        buf.extend(chunk)
        if len(buf) > s.max_upload_bytes:
            raise AppError(413, "file_too_large", f"The video is larger than {s.max_upload_mb} MB.")
    data = bytes(buf)

    try:
        info = validate_upload(
            filename=file.filename or "",
            declared_mime=file.content_type,
            data=data,
            allowed_extensions=s.extension_list,
            max_bytes=s.max_upload_bytes,
            min_seconds=s.min_video_seconds,
            max_seconds=s.max_video_seconds,
        )
    except MediaError as e:
        raise AppError(e.status, e.code, e.message) from e

    video_id = str(uuid.uuid4())
    path = f"{user.id}/{project_id}/{video_id}.{info.extension}"  # server-generated; never from user input
    try:
        c.storage.upload(path, data, info.mime_type)
    except Exception as e:  # noqa: BLE001
        log.exception("Storage upload failed")
        raise AppError(
            502, "storage_unavailable", "Could not store the video. Try again shortly."
        ) from e
    try:
        row = c.repo.insert(
            "videos",
            {
                "id": video_id,
                "user_id": user.id,
                "project_id": project_id,
                "storage_path": path,
                "original_filename": (file.filename or "video")[:200],
                "mime_type": info.mime_type,
                "size_bytes": len(data),
                "duration_seconds": info.duration_seconds,
            },
        )
    except Exception:
        c.storage.remove([path])  # do not leave orphaned files
        raise
    return row


@router.get(
    "/projects/{project_id}/videos", response_model=VideoPage, summary="List a project's videos"
)
def list_videos(
    project_id: str,
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    user: CurrentUser = Depends(current_user),
    c: Container = Depends(get_container),
):
    owned_project(c, user.id, project_id)
    where = {"project_id": project_id, "user_id": user.id}
    return {
        "items": c.repo.select("videos", where, order="created_at", limit=limit, offset=offset),
        "total": c.repo.count("videos", where),
        "limit": limit,
        "offset": offset,
    }


@router.get("/videos/{video_id}", response_model=VideoOut, summary="Get video metadata")
def get_video(
    video_id: str, user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)
):
    return owned_video(c, user.id, video_id)


@router.get(
    "/videos/{video_id}/url",
    response_model=SignedUrlOut,
    summary="Short-lived signed URL for playback",
)
def video_url(
    video_id: str, user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)
):
    v = owned_video(c, user.id, video_id)  # ownership verified before any URL is signed
    ttl = c.settings.signed_url_ttl_seconds
    try:
        url = c.storage.signed_url(v["storage_path"], ttl)
    except Exception as e:  # noqa: BLE001
        raise AppError(
            502, "storage_unavailable", "Could not create a video link right now."
        ) from e
    return SignedUrlOut(url=url, expires_in=ttl)


@router.delete("/videos/{video_id}", status_code=204, summary="Delete a video")
def delete_video(
    video_id: str, user: CurrentUser = Depends(current_user), c: Container = Depends(get_container)
):
    v = owned_video(c, user.id, video_id)
    if c.repo.count("analysis_jobs", {"video_id": video_id, "status": ("in", list(ACTIVE))}):
        raise conflict(
            "analysis_in_progress", "This video is being analysed. Wait for the analysis to finish."
        )
    try:
        c.storage.remove([v["storage_path"]])
    except Exception:  # noqa: BLE001
        log.warning("Stored file for video %s could not be removed", video_id)
    c.repo.delete("videos", {"id": video_id, "user_id": user.id})
    return Response(status_code=204)

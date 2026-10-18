"""Seeding helpers shared by pipeline and API tests (no pytest fixtures needed)."""

from app.services.worker import Worker
from tests.fakes import FakeAuth, make_container
from tests.samples import mp4_bytes

ALICE = FakeAuth.USERS["token-alice"].id
BOB = FakeAuth.USERS["token-bob"].id


def seed_project(c, user_id=ALICE, name="My project"):
    return c.repo.insert("projects", {"user_id": user_id, "name": name})


def seed_video(c, project, user_id=ALICE, path=None):
    path = path or f"{user_id}/{project['id']}/vid-{len(c.repo.tables['videos'])}.mp4"
    c.storage.upload(path, mp4_bytes(12), "video/mp4")
    return c.repo.insert(
        "videos",
        {
            "user_id": user_id,
            "project_id": project["id"],
            "storage_path": path,
            "original_filename": "clip.mp4",
            "mime_type": "video/mp4",
            "size_bytes": 3000,
            "duration_seconds": 12,
        },
    )


def seed_job(c, project, video=None, user_id=ALICE, **over):
    row = {
        "user_id": user_id,
        "project_id": project["id"],
        "video_id": video["id"] if video else None,
        "input_type": "video" if video else "script",
        "script_text": None
        if video
        else "Scene one: a hand reveals a surprising kitchen trick. Scene two: ...",
        "platform": "tiktok",
        "niche": "cooking",
        "target_audience": "students",
        "caption": "Meal prep!",
        "status": "queued",
        "stage": "queued",
        "progress": 0,
        "attempts": 0,
        "max_attempts": c.settings.max_job_attempts,
    }
    return c.repo.insert("analysis_jobs", {**row, **over})


def env(with_video=True, **settings_over):
    c = make_container(**settings_over)
    project = seed_project(c)
    video = seed_video(c, project) if with_video else None
    job = seed_job(c, project, video)
    return c, project, video, job, Worker(c)


def job_row(c, job_id):
    return c.repo.select("analysis_jobs", {"id": job_id})[0]


def report_for(c, job_id):
    rows = c.repo.select("reports", {"job_id": job_id})
    return rows[0] if rows else None

ACTIVE = ("queued", "processing")


def job_out(job: dict, scores: dict | None = None, project_name: str | None = None) -> dict:
    retryable = (
        job["status"] == "failed"
        and job.get("error_code") != "content_blocked"
        and int(job.get("attempts") or 0) < int(job.get("max_attempts") or 0)
        and (job["input_type"] == "script" or job.get("video_id") is not None)
    )
    out = {k: job.get(k) for k in (
        "id", "project_id", "video_id", "input_type", "platform", "niche", "target_audience", "caption",
        "status", "stage", "progress", "attempts", "max_attempts", "error_code", "error_message",
        "created_at", "started_at", "completed_at")}
    out.update(retryable=retryable, scores=scores, project_name=project_name)
    return out

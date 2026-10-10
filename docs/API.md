# API contract (v1)

Base URL: `http://localhost:8000/api/v1`. Interactive docs: `/docs`, schema: `/openapi.json`.
All routes except `/health`, `/health/ready` and `/config` need `Authorization: Bearer <Supabase access token>`.

## Errors
Every error uses one shape:
```json
{"error": {"code": "not_found", "message": "Project not found.", "details": null, "request_id": "a1b2c3"}}
```
| Status | Codes |
|---|---|
| 401 | `not_authenticated`, `invalid_token` |
| 404 | `not_found` (also returned for other users' resources, so ids are never confirmed) |
| 409 | `analysis_in_progress`, `already_analyzed`, `not_retryable` |
| 413 | `file_too_large` |
| 422 | `validation_error` (details: `[{field, message}]`), `unsupported_extension`, `unsupported_media`, `extension_mismatch`, `mime_mismatch`, `empty_or_tiny_file`, `duration_unreadable`, `video_too_short`, `video_too_long` |
| 429 | `rate_limited` (with `Retry-After`) |
| 502/503 | `storage_unavailable`, `auth_unavailable`, `model_unavailable` |

## Endpoints
Lists are paginated: `?limit=1..100&offset=0` → `{items, total, limit, offset}`.

| Method & path | Purpose | Success |
|---|---|---|
| `GET /health` · `GET /health/ready` · `GET /config` | liveness · readiness (config, DB, Gemini model; 503 when degraded) · public upload limits | 200 |
| `GET /me` | current user | 200 |
| `POST /projects` · `GET /projects` | create · list (newest updated first) | 201 · 200 |
| `GET/PATCH/DELETE /projects/{id}` | read · edit · delete (cascades; 409 if an analysis is active) | 200 · 200 · 204 |
| `POST /projects/{id}/videos` (multipart `file`) | validated upload | 201 `VideoOut` |
| `GET /projects/{id}/videos` | list videos | 200 |
| `GET /videos/{id}` · `GET /videos/{id}/url` · `DELETE /videos/{id}` | metadata · signed URL (`{url, expires_in}`) · delete (409 if analysing) | 200 · 200 · 204 |
| `POST /projects/{id}/analyses` | start analysis (returns immediately) | 202 `JobOut` |
| `GET /projects/{id}/analyses` · `GET /history` | analyses of a project · of the user (includes `scores`, `project_name`) | 200 |
| `GET /analyses/{id}` | status; includes `report` when completed | 200 |
| `GET /analyses/{id}/report` | full report (404 until completed) | 200 `ReportOut` |
| `POST /analyses/{id}/retry` | retry a failed, retryable job | 202 |
| `DELETE /analyses/{id}` | delete job and report (409 if active) | 204 |

### Start analysis body
```json
{"input_type": "video", "video_id": "<uuid>", "platform": "tiktok",
 "niche": "Budget cooking", "target_audience": "College students", "caption": "optional"}
```
`input_type: "script"` takes `script_text` (20 to 8000 chars) instead of `video_id`. `platform` is `instagram_reels | tiktok | youtube_shorts`.

## Job lifecycle
`status`: `queued → processing → completed | failed`. `stage` / `progress` refine it:
`queued 0`, `validating 5`, `preparing_video 10`, `uploading 25`, `moderating 35`, `analyzing 50`,
`simulating_audience 80`, `finalizing 95`, `completed 100`. A transient provider error sets `stage = retrying`
and re-queues the job (backoff 20 s × attempt). Failed jobs carry `error_code`, `error_message` and `retryable`.
Error codes: `content_blocked`, `moderation_unavailable`, `model_unavailable`, `ai_service_unavailable`,
`ai_response_invalid`, `video_unprocessable`, `video_missing`, `storage_unavailable`, `worker_timeout`, `internal_error`.

## Report (`report` object, `schema_version` 1)
`scores{hook, engagement, retention, shareability, overall}` (0 to 100 ints), `verdict`, `dimensions[7]`
(`key,label,score 1-10,rationale`), `rubric`, `content_summary`, `strengths[]`, `weaknesses[]`,
`recommendations[{priority,title,detail,expected_impact}]`, `observations[{area,observation,evidence}]`,
`confidence`, `confidence_note`, `personas{label,status,expected,received,note,items[10]}`, `disclaimer`, `model`, `generated_at`.
`personas.status` is `complete`, `partial` or `failed`; each item is `ok` or `missing`.

from app.ai_schemas import ModerationVerdict
from app.services.gemini import MalformedResponse
from tests.api_helpers import ANALYSIS, API, make_project, make_video, start_analysis, upload


def setup_video(client, headers):
    p = make_project(client, headers)
    return p, make_video(client, headers, p["id"])


def test_create_returns_immediately_as_queued(client, alice, container):
    p, v = setup_video(client, alice)
    r = start_analysis(client, alice, p["id"], v["id"])
    assert r.status_code == 202
    job = r.json()
    assert (job["status"], job["progress"], job["input_type"]) == ("queued", 0, "video")
    assert container.gemini.calls == []  # nothing expensive happened in the request


def test_full_workflow_video_to_report_history_and_isolation(client, alice, bob, worker, container):
    p, v = setup_video(client, alice)
    job = start_analysis(client, alice, p["id"], v["id"]).json()
    assert client.get(f"{API}/analyses/{job['id']}", headers=alice).json()["status"] == "queued"
    assert client.get(f"{API}/analyses/{job['id']}/report", headers=alice).status_code == 404  # not ready

    assert worker.run_once()
    got = client.get(f"{API}/analyses/{job['id']}", headers=alice).json()
    assert got["status"] == "completed" and got["progress"] == 100
    report = got["report"]
    assert set(report["scores"]) == {"hook", "engagement", "retention", "shareability", "overall"}
    assert len(report["personas"]["items"]) == 10 and "AI-simulated" in report["personas"]["label"]
    assert report["disclaimer"] and report["rubric"]["formulas"]

    r = client.get(f"{API}/analyses/{job['id']}/report", headers=alice)
    assert r.status_code == 200 and r.json()["scores"] == report["scores"]

    hist = client.get(f"{API}/history", headers=alice).json()
    assert hist["total"] == 1 and hist["items"][0]["scores"]["overall"] == report["scores"]["overall"]
    assert hist["items"][0]["project_name"] == p["name"]
    assert client.get(f"{API}/projects/{p['id']}/analyses", headers=alice).json()["total"] == 1
    assert client.get(f"{API}/projects/{p['id']}", headers=alice).json()["analysis_count"] == 1

    # Another user can reach none of it
    for url in (f"{API}/analyses/{job['id']}", f"{API}/analyses/{job['id']}/report"):
        assert client.get(url, headers=bob).status_code == 404
    assert client.post(f"{API}/analyses/{job['id']}/retry", headers=bob).status_code == 404
    assert client.delete(f"{API}/analyses/{job['id']}", headers=bob).status_code == 404
    assert client.get(f"{API}/history", headers=bob).json()["total"] == 0
    assert client.get(f"{API}/projects/{p['id']}/analyses", headers=bob).status_code == 404
    assert start_analysis(client, bob, p["id"], v["id"]).status_code == 404

    assert client.delete(f"{API}/analyses/{job['id']}", headers=alice).status_code == 204
    assert client.get(f"{API}/analyses/{job['id']}", headers=alice).status_code == 404


def test_duplicate_submissions_are_rejected(client, alice, worker):
    p, v = setup_video(client, alice)
    assert start_analysis(client, alice, p["id"], v["id"]).status_code == 202
    r = start_analysis(client, alice, p["id"], v["id"])
    assert r.status_code == 409 and r.json()["error"]["code"] == "analysis_in_progress"
    worker.run_once()
    r = start_analysis(client, alice, p["id"], v["id"])
    assert r.status_code == 409 and r.json()["error"]["code"] == "already_analyzed"


def test_input_validation(client, alice):
    p, v = setup_video(client, alice)
    url = f"{API}/projects/{p['id']}/analyses"
    bad = [
        {"input_type": "video", **ANALYSIS},  # no video_id
        {"input_type": "video", "video_id": v["id"], "script_text": "x" * 40, **ANALYSIS},
        {"input_type": "script", "script_text": "too short", **ANALYSIS},
        {"input_type": "script", "script_text": "x" * 40, "video_id": v["id"], **ANALYSIS},
        {"input_type": "video", "video_id": v["id"], **{**ANALYSIS, "platform": "myspace"}},
        {"input_type": "video", "video_id": v["id"], **{**ANALYSIS, "niche": ""}},
        {"input_type": "video", "video_id": v["id"], **{**ANALYSIS, "caption": "c" * 2201}},
    ]
    for body in bad:
        assert client.post(url, json=body, headers=alice).status_code == 422, body


def test_script_analysis_runs_without_video(client, alice, worker, container):
    p = make_project(client, alice)
    body = {"input_type": "script", "script_text": "Scene 1: a surprising hook about saving money. " * 3, **ANALYSIS}
    job = client.post(f"{API}/projects/{p['id']}/analyses", json=body, headers=alice).json()
    worker.run_once()
    assert client.get(f"{API}/analyses/{job['id']}", headers=alice).json()["report"]["input_type"] == "script"
    assert container.gemini.uploads == []


def test_video_must_belong_to_the_project_and_user(client, alice, bob):
    p, v = setup_video(client, alice)
    other = make_project(client, alice, "Other")
    assert start_analysis(client, alice, other["id"], v["id"]).status_code == 404
    assert start_analysis(client, alice, p["id"], "00000000-0000-0000-0000-000000000000").status_code == 404


def test_unavailable_model_gives_clear_error_and_no_job(client, alice, container):
    p, v = setup_video(client, alice)
    container.gemini.model_ok = False
    container.model_status.checked_at = 0
    r = start_analysis(client, alice, p["id"], v["id"])
    assert r.status_code == 503 and r.json()["error"]["code"] == "model_unavailable"
    assert "not available" in r.json()["error"]["message"] and container.repo.tables["analysis_jobs"] == []


def test_failed_job_can_be_retried(client, alice, worker, container):
    p, v = setup_video(client, alice)
    job = start_analysis(client, alice, p["id"], v["id"]).json()
    container.gemini.errors["ContentAnalysis"] = MalformedResponse("bad")
    worker.run_once()
    failed = client.get(f"{API}/analyses/{job['id']}", headers=alice).json()
    assert failed["status"] == "failed" and failed["error_code"] == "ai_response_invalid" and failed["retryable"]
    r = client.post(f"{API}/analyses/{job['id']}/retry", headers=alice)
    assert r.status_code == 202 and r.json()["status"] == "queued" and r.json()["error_code"] is None
    assert client.post(f"{API}/analyses/{job['id']}/retry", headers=alice).status_code == 409  # not failed any more
    worker.run_once()
    assert client.get(f"{API}/analyses/{job['id']}", headers=alice).json()["status"] == "completed"


def test_blocked_content_is_not_retryable_and_video_removed(client, alice, worker, container):
    p, v = setup_video(client, alice)
    job = start_analysis(client, alice, p["id"], v["id"]).json()
    container.gemini.verdict = ModerationVerdict(allowed=False, categories=["hate_or_harassment"], reason="x")
    worker.run_once()
    got = client.get(f"{API}/analyses/{job['id']}", headers=alice).json()
    assert got["error_code"] == "content_blocked" and got["retryable"] is False
    assert client.post(f"{API}/analyses/{job['id']}/retry", headers=alice).status_code == 409
    assert client.get(f"{API}/videos/{v['id']}", headers=alice).status_code == 404 and container.storage.objects == {}


def test_cannot_delete_active_analysis(client, alice):
    p, v = setup_video(client, alice)
    job = start_analysis(client, alice, p["id"], v["id"]).json()
    r = client.delete(f"{API}/analyses/{job['id']}", headers=alice)
    assert r.status_code == 409 and r.json()["error"]["code"] == "analysis_in_progress"


def test_analysis_rate_limit(client, alice, container):
    container.settings.analysis_limit_per_hour = 1
    p = make_project(client, alice)
    body = {"input_type": "script", "script_text": "A script that is long enough to pass validation.", **ANALYSIS}
    assert client.post(f"{API}/projects/{p['id']}/analyses", json=body, headers=alice).status_code == 202
    assert client.post(f"{API}/projects/{p['id']}/analyses", json=body, headers=alice).status_code == 429

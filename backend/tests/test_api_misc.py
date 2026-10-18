from tests.api_helpers import API


def test_health_and_config(client):
    assert client.get(f"{API}/health").json() == {
        "status": "ok",
        "service": "viralforge-experiment",
    }
    cfg = client.get(f"{API}/config").json()
    assert cfg["allowed_extensions"] == ["mp4", "webm", "mov"] and cfg["max_upload_mb"] == 5


def test_ready_reports_model_problem(client, container):
    assert client.get(f"{API}/health/ready").status_code == 200
    container.gemini.model_ok = False
    container.model_status.checked_at = 0
    r = client.get(f"{API}/health/ready")
    assert r.status_code == 503 and r.json()["checks"]["gemini_model"]["ok"] is False


def test_me(client, alice):
    assert client.get(f"{API}/me", headers=alice).json()["email"] == "alice@example.com"


def test_unknown_route_uses_error_shape(client):
    r = client.get(f"{API}/nope")
    assert r.status_code == 404 and r.json()["error"]["code"] == "not_found"


def test_openapi_documents_all_resources(client):
    spec = client.get("/openapi.json").json()
    paths = set(spec["paths"])
    for p in (
        "/api/v1/health",
        "/api/v1/projects",
        "/api/v1/projects/{project_id}",
        "/api/v1/projects/{project_id}/videos",
        "/api/v1/videos/{video_id}/url",
        "/api/v1/projects/{project_id}/analyses",
        "/api/v1/analyses/{job_id}",
        "/api/v1/analyses/{job_id}/report",
        "/api/v1/analyses/{job_id}/retry",
        "/api/v1/history",
    ):
        assert p in paths, p
    assert client.get("/docs").status_code == 200


def test_cors_preflight_allows_local_frontend_only(client):
    ok = client.options(
        f"{API}/projects",
        headers={
            "Origin": "http://localhost:5173",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization",
        },
    )
    assert ok.headers.get("access-control-allow-origin") == "http://localhost:5173"
    bad = client.options(
        f"{API}/projects",
        headers={"Origin": "http://evil.example", "Access-Control-Request-Method": "GET"},
    )
    assert "access-control-allow-origin" not in bad.headers


def test_security_headers(client):
    r = client.get(f"{API}/health")
    assert r.headers["x-content-type-options"] == "nosniff" and r.headers["x-request-id"]

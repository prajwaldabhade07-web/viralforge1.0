from tests.api_helpers import API, make_project, make_video, start_analysis, upload
from tests.samples import mp4_bytes, webm_bytes


def test_valid_upload_is_private_and_owned(client, alice, container):
    p = make_project(client, alice)
    r = upload(client, alice, p["id"])
    assert r.status_code == 201
    body = r.json()
    assert (
        body["mime_type"] == "video/mp4"
        and body["duration_seconds"] == 12
        and "storage_path" not in body
    )
    (path,) = container.storage.objects
    assert path.startswith(f"11111111-1111-1111-1111-111111111111/{p['id']}/") and path.endswith(
        ".mp4"
    )
    assert upload(client, alice, p["id"], webm_bytes(8), "a.webm", "video/webm").status_code == 201


def test_rejects_invalid_uploads(client, alice, container):
    p = make_project(client, alice)
    cases = [
        (b"MZ" + b"\x00" * 4000, "evil.mp4", "video/mp4", 422, "unsupported_media"),
        (mp4_bytes(), "clip.exe", "video/mp4", 422, "unsupported_extension"),
        (mp4_bytes(), "clip.mp4", "video/webm", 422, "mime_mismatch"),
        (mp4_bytes(300), "long.mp4", "video/mp4", 422, "video_too_long"),
        (b"", "empty.mp4", "video/mp4", 422, "empty_or_tiny_file"),
        (
            mp4_bytes(pad=6 * 1024 * 1024),
            "big.mp4",
            "video/mp4",
            413,
            "file_too_large",
        ),  # limit is 5 MB in tests
    ]
    for data, name, mime, status, code in cases:
        r = upload(client, alice, p["id"], data, name, mime)
        assert (r.status_code, r.json()["error"]["code"]) == (status, code), code
    assert container.storage.objects == {} and container.repo.tables["videos"] == []


def test_upload_requires_owned_project(client, alice, bob):
    p = make_project(client, alice)
    assert upload(client, bob, p["id"]).status_code == 404
    assert upload(client, alice, "00000000-0000-0000-0000-000000000000").status_code == 404


def test_other_users_cannot_access_video(client, alice, bob):
    p = make_project(client, alice)
    v = make_video(client, alice, p["id"])
    assert client.get(f"{API}/videos/{v['id']}", headers=bob).status_code == 404
    assert client.get(f"{API}/videos/{v['id']}/url", headers=bob).status_code == 404
    assert client.delete(f"{API}/videos/{v['id']}", headers=bob).status_code == 404
    assert client.get(f"{API}/projects/{p['id']}/videos", headers=bob).status_code == 404
    assert client.get(f"{API}/videos/{v['id']}/url", headers=alice).status_code == 200


def test_signed_url_is_short_lived(client, alice, container):
    p = make_project(client, alice)
    v = make_video(client, alice, p["id"])
    body = client.get(f"{API}/videos/{v['id']}/url", headers=alice).json()
    assert body["expires_in"] == container.settings.signed_url_ttl_seconds <= 600
    assert body["url"].startswith("https://")


def test_delete_video_removes_file(client, alice, container):
    p = make_project(client, alice)
    v = make_video(client, alice, p["id"])
    assert client.delete(f"{API}/videos/{v['id']}", headers=alice).status_code == 204
    assert (
        container.storage.objects == {}
        and client.get(f"{API}/videos/{v['id']}", headers=alice).status_code == 404
    )


def test_cannot_delete_video_being_analysed(client, alice):
    p = make_project(client, alice)
    v = make_video(client, alice, p["id"])
    assert start_analysis(client, alice, p["id"], v["id"]).status_code == 202
    r = client.delete(f"{API}/videos/{v['id']}", headers=alice)
    assert r.status_code == 409 and r.json()["error"]["code"] == "analysis_in_progress"


def test_upload_rate_limit(alice, client, container):
    container.settings.upload_limit_per_hour = 2
    p = make_project(client, alice)
    assert upload(client, alice, p["id"]).status_code == 201
    assert upload(client, alice, p["id"]).status_code == 201
    r = upload(client, alice, p["id"])
    assert (
        r.status_code == 429
        and r.json()["error"]["code"] == "rate_limited"
        and "retry-after" in r.headers
    )


def test_list_videos(client, alice):
    p = make_project(client, alice)
    make_video(client, alice, p["id"])
    make_video(client, alice, p["id"])
    page = client.get(f"{API}/projects/{p['id']}/videos?limit=1", headers=alice).json()
    assert page["total"] == 2 and len(page["items"]) == 1

from tests.api_helpers import API, make_project, make_video


def test_requires_authentication(client):
    r = client.get(f"{API}/projects")
    assert r.status_code == 401 and r.json()["error"]["code"] == "not_authenticated"
    r = client.get(f"{API}/projects", headers={"Authorization": "Bearer forged"})
    assert r.status_code == 401 and r.json()["error"]["code"] == "invalid_token"


def test_project_crud(client, alice):
    p = make_project(client, alice)
    assert p["name"] == "Launch videos" and p["analysis_count"] == 0
    r = client.patch(f"{API}/projects/{p['id']}", json={"niche": "fitness", "platform": "tiktok"}, headers=alice)
    assert r.status_code == 200 and r.json()["niche"] == "fitness" and r.json()["name"] == "Launch videos"
    assert client.get(f"{API}/projects/{p['id']}", headers=alice).json()["platform"] == "tiktok"
    assert client.delete(f"{API}/projects/{p['id']}", headers=alice).status_code == 204
    assert client.get(f"{API}/projects/{p['id']}", headers=alice).status_code == 404


def test_validation_errors_use_standard_shape(client, alice):
    r = client.post(f"{API}/projects", json={"name": "   "}, headers=alice)
    assert r.status_code == 422
    err = r.json()["error"]
    assert err["code"] == "validation_error" and err["details"] and err["request_id"]
    assert client.post(f"{API}/projects", json={"name": "x", "platform": "myspace"}, headers=alice).status_code == 422
    assert client.post(f"{API}/projects", json={"name": "x" * 101}, headers=alice).status_code == 422


def test_pagination(client, alice):
    for i in range(3):
        make_project(client, alice, f"P{i}")
    page = client.get(f"{API}/projects?limit=2&offset=2", headers=alice).json()
    assert (page["total"], page["limit"], page["offset"], len(page["items"])) == (3, 2, 2, 1)
    assert client.get(f"{API}/projects?limit=0", headers=alice).status_code == 422
    assert client.get(f"{API}/projects?limit=101", headers=alice).status_code == 422


def test_other_users_cannot_see_or_change_projects(client, alice, bob):
    p = make_project(client, alice)
    assert client.get(f"{API}/projects", headers=bob).json()["total"] == 0
    for method, kwargs in (("get", {}), ("patch", {"json": {"name": "hacked"}}), ("delete", {})):
        r = getattr(client, method)(f"{API}/projects/{p['id']}", headers=bob, **kwargs)
        assert r.status_code == 404 and r.json()["error"]["code"] == "not_found"
    assert client.get(f"{API}/projects/{p['id']}", headers=alice).json()["name"] == "Launch videos"


def test_delete_project_removes_stored_files(client, alice, container):
    p = make_project(client, alice)
    make_video(client, alice, p["id"])
    assert len(container.storage.objects) == 1
    assert client.delete(f"{API}/projects/{p['id']}", headers=alice).status_code == 204
    assert container.storage.objects == {} and container.repo.tables["videos"] == []


def test_delete_project_blocked_while_analysis_active(client, alice):
    from tests.api_helpers import start_analysis
    p = make_project(client, alice)
    v = make_video(client, alice, p["id"])
    assert start_analysis(client, alice, p["id"], v["id"]).status_code == 202
    r = client.delete(f"{API}/projects/{p['id']}", headers=alice)
    assert r.status_code == 409 and r.json()["error"]["code"] == "analysis_in_progress"

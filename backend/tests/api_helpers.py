from tests.samples import mp4_bytes

API = "/api/v1"
ANALYSIS = {"platform": "tiktok", "niche": "cooking", "target_audience": "students", "caption": "Meal prep!"}


def make_project(client, headers, name="Launch videos"):
    r = client.post(f"{API}/projects", json={"name": name}, headers=headers)
    assert r.status_code == 201, r.text
    return r.json()


def upload(client, headers, project_id, data=None, name="clip.mp4", mime="video/mp4"):
    return client.post(f"{API}/projects/{project_id}/videos", headers=headers,
                       files={"file": (name, data if data is not None else mp4_bytes(12), mime)})


def make_video(client, headers, project_id):
    r = upload(client, headers, project_id)
    assert r.status_code == 201, r.text
    return r.json()


def start_analysis(client, headers, project_id, video_id, **over):
    return client.post(f"{API}/projects/{project_id}/analyses", headers=headers,
                       json={"input_type": "video", "video_id": video_id, **ANALYSIS, **over})

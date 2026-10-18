from types import SimpleNamespace

import pytest
from pydantic import BaseModel

from app.auth import SupabaseAuthVerifier
from app.errors import AppError
from app.rate_limit import RateLimiter
from app.services.gemini import (
    GoogleGenaiGateway,
    MalformedResponse,
    ModelUnavailable,
    ProviderError,
)


class Tiny(BaseModel):
    x: int


class ApiErr(Exception):
    def __init__(self, code):
        super().__init__(f"http {code}")
        self.code = code


def gateway(responses, max_attempts=3):
    """GoogleGenaiGateway wired to a scripted client (no SDK call, no network)."""
    g = GoogleGenaiGateway.__new__(GoogleGenaiGateway)
    g.model, g.max_attempts, g.file_ready_timeout_s = "test-model", max_attempts, 5
    g.sleeps = []
    g._sleep = g.sleeps.append
    g._types = SimpleNamespace(GenerateContentConfig=lambda **kw: kw)
    queue = list(responses)

    def generate_content(model, contents, config):
        item = queue.pop(0)
        if isinstance(item, Exception):
            raise item
        return SimpleNamespace(text=item)

    def get(model):
        item = queue.pop(0)
        if isinstance(item, Exception):
            raise item

    g.client = SimpleNamespace(models=SimpleNamespace(generate_content=generate_content, get=get))
    g.queue = queue
    return g


def run(g):
    return g.generate_json(system="s", prompt="p", schema=Tiny)


def test_valid_json_and_code_fences():
    assert run(gateway(['{"x": 3}'])).x == 3
    assert run(gateway(['```json\n{"x": 4}\n```'])).x == 4


def test_transient_errors_retried_with_backoff_then_succeed():
    g = gateway([ApiErr(429), ApiErr(503), '{"x": 1}'])
    assert run(g).x == 1 and len(g.sleeps) == 2


def test_transient_errors_exhausted_raise_provider_error():
    g = gateway([ApiErr(503)] * 3)
    with pytest.raises(ProviderError) as e:
        run(g)
    assert e.value.transient is True


def test_malformed_then_valid_uses_repair_retry():
    g = gateway(["not json at all", '{"x": 2}'])
    assert run(g).x == 2 and g.queue == []


def test_always_malformed_raises_malformed_response():
    with pytest.raises(MalformedResponse):
        run(gateway(["nope", "", "{bad"]))


def test_auth_and_missing_model_errors_are_not_retried():
    for code in (401, 403, 404):
        g = gateway([ApiErr(code), '{"x": 1}'])
        with pytest.raises(ModelUnavailable):
            run(g)
        assert len(g.queue) == 1  # only one call was made


def test_client_error_is_permanent_provider_error():
    g = gateway([ApiErr(400), '{"x": 1}'])
    with pytest.raises(ProviderError) as e:
        run(g)
    assert e.value.transient is False and len(g.queue) == 1


def test_check_model_messages():
    gateway([None]).check_model()
    with pytest.raises(ModelUnavailable) as e:
        gateway([ApiErr(404)]).check_model()
    assert "test-model" in str(e.value) and "GEMINI_MODEL" in str(e.value)
    with pytest.raises(ModelUnavailable) as e:
        gateway([ApiErr(403)]).check_model()
    assert "GEMINI_API_KEY" in str(e.value)


class AuthErrorLike(Exception):
    status = 401


def verifier(behaviour):
    calls = []

    def get_user(token):
        calls.append(token)
        if isinstance(behaviour, Exception):
            raise behaviour
        return behaviour

    return SupabaseAuthVerifier(SimpleNamespace(auth=SimpleNamespace(get_user=get_user))), calls


def test_auth_valid_token_is_cached():
    user = SimpleNamespace(id="u1", email="a@b.c")
    v, calls = verifier(SimpleNamespace(user=user))
    assert v.verify("tok").id == "u1" and v.verify("tok").email == "a@b.c"
    assert len(calls) == 1


def test_auth_invalid_and_unreachable():
    v, _ = verifier(AuthErrorLike("bad jwt"))
    with pytest.raises(AppError) as e:
        v.verify("x")
    assert (e.value.status_code, e.value.code) == (401, "invalid_token")
    v, _ = verifier(SimpleNamespace(user=None))
    with pytest.raises(AppError) as e:
        v.verify("x")
    assert e.value.status_code == 401
    v, _ = verifier(ConnectionError("down"))
    with pytest.raises(AppError) as e:
        v.verify("x")
    assert (e.value.status_code, e.value.code) == (503, "auth_unavailable")


def test_rate_limiter_window_and_isolation():
    rl = RateLimiter()
    for _ in range(3):
        rl.hit("r", "alice", 3, 60)
    with pytest.raises(AppError) as e:
        rl.hit("r", "alice", 3, 60)
    assert e.value.status_code == 429 and int(e.value.headers["Retry-After"]) >= 1
    rl.hit("r", "bob", 3, 60)  # other users unaffected
    rl.hit("other", "alice", 3, 60)  # other rules unaffected

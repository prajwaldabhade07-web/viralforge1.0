import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.services.worker import Worker
from tests.fakes import make_container


@pytest.fixture
def container():
    return make_container()


@pytest.fixture
def client(container):
    return TestClient(create_app(container, start_worker=False))


@pytest.fixture
def worker(container):
    return Worker(container)


@pytest.fixture
def alice():
    return {"Authorization": "Bearer token-alice"}


@pytest.fixture
def bob():
    return {"Authorization": "Bearer token-bob"}

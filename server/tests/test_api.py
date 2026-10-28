import asyncio
import io
import time
from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from uuid import uuid4

import pytest
from fastapi.testclient import TestClient
from PIL import Image

from app.config import Settings
from app.main import create_app
from app.provider import ProviderError, normalize_image
from app.repository import Repository
from app.schemas import ArtworkRequest


class TestProvider:
    __test__ = False
    configured = True
    calls = 0

    async def generate(self, _request):
        self.calls += 1
        await asyncio.sleep(0.02)
        output = io.BytesIO()
        Image.new("RGB", (256, 256), "blue").save(output, format="PNG")
        return output.getvalue()


@pytest.fixture
def setup(tmp_path):
    return Settings(data_dir=tmp_path, api_tokens=("alice", "bob")), TestProvider()


def headers(token="alice", key=None):
    return {"Authorization": f"Bearer {token}", "Idempotency-Key": key or str(uuid4())}


def wait_for_job(client, ident, auth):
    deadline = time.monotonic() + 6
    while time.monotonic() < deadline:
        response = client.get(f"/v1/artwork-jobs/{ident}", headers=auth)
        assert response.status_code == 200
        if response.json()["status"] in ("succeeded", "failed", "cancelled"):
            return response.json()
        time.sleep(0.02)
    pytest.fail("Worker did not finish")


def test_generation_and_ownership(setup):
    config, provider = setup
    with TestClient(create_app(config, provider)) as client:
        auth = headers()
        created = client.post("/v1/artwork-jobs", headers=auth, json={"prompt": "山野"})
        assert created.status_code == 202
        ident = created.json()["id"]
        assert wait_for_job(client, ident, auth)["status"] == "succeeded"
        image = client.get(f"/v1/artwork-jobs/{ident}/image", headers=auth)
        assert image.status_code == 200
        assert image.content.startswith(b"\x89PNG")
        assert client.get(f"/v1/artwork-jobs/{ident}", headers=headers("bob")).status_code == 404
        assert client.get(f"/v1/artwork-jobs/{ident}/image").status_code == 401
        assert provider.calls == 1


def test_idempotency_and_conflict(setup):
    config, provider = setup
    with TestClient(create_app(config, provider)) as client:
        auth = headers()

        def submit():
            return client.post("/v1/artwork-jobs", headers=auth, json={"prompt": "同一请求"})

        with ThreadPoolExecutor(max_workers=4) as executor:
            results = list(executor.map(lambda _: submit(), range(4)))
        assert all(result.status_code == 202 for result in results)
        assert len({result.json()["id"] for result in results}) == 1
        assert (
            client.post("/v1/artwork-jobs", headers=auth, json={"prompt": "不同内容"}).status_code
            == 409
        )


def test_auth_validation_and_missing_provider(setup):
    config, _ = setup
    with TestClient(create_app(config)) as client:
        assert client.get("/health").status_code == 200
        assert (
            client.post(
                "/v1/artwork-jobs", headers=headers("wrong"), json={"prompt": "a"}
            ).status_code
            == 401
        )
        assert (
            client.post("/v1/artwork-jobs", headers=headers(), json={"prompt": " "}).status_code
            == 422
        )
        assert (
            client.post(
                "/v1/artwork-jobs", headers=headers(), json={"prompt": "a", "width": 99999}
            ).status_code
            == 422
        )
        assert (
            client.post("/v1/artwork-jobs", headers=headers(), json={"prompt": "a"}).status_code
            == 503
        )


def test_failure_is_visible_without_provider_secrets(setup):
    config, provider = setup

    async def bad(_):
        raise RuntimeError("secret upstream credential")

    provider.generate = bad
    with TestClient(create_app(config, provider)) as client:
        auth = headers()
        ident = client.post("/v1/artwork-jobs", headers=auth, json={"prompt": "x"}).json()["id"]
        job = wait_for_job(client, ident, auth)
        assert job["status"] == "failed"
        assert "secret" not in job["error"]
        assert client.get(f"/v1/artwork-jobs/{ident}/image", headers=auth).status_code == 409


def test_cancel_does_not_turn_into_success(setup):
    config, provider = setup
    with TestClient(create_app(config, provider)) as client:
        auth = headers()
        ident = client.post("/v1/artwork-jobs", headers=auth, json={"prompt": "x"}).json()["id"]
        result = client.delete(f"/v1/artwork-jobs/{ident}", headers=auth)
        assert result.json()["status"] == "cancelled"
        time.sleep(1.2)
        assert wait_for_job(client, ident, auth)["status"] == "cancelled"
        assert not (config.data_dir / "artworks" / f"{ident}.png").exists()


def test_feedback_rate_limit_and_persistence(setup):
    config, provider = setup
    config = replace(config, feedback_per_minute=1)
    with TestClient(create_app(config, provider)) as client:
        payload = {"category": "建议", "details": "完善设备选择", "contact": ""}
        assert client.post("/v1/feedback", headers=headers(), json=payload).status_code == 201
        assert client.post("/v1/feedback", headers=headers(), json=payload).status_code == 429
        assert client.post("/v1/feedback", headers=headers("bob"), json=payload).status_code == 201
    with Repository(config.data_dir).connection() as db:
        assert db.execute("SELECT COUNT(*) FROM feedback").fetchone()[0] == 2


def test_restart_recovery_keeps_job_identity(setup):
    config, _ = setup
    repository = Repository(config.data_dir)
    job = repository.create_job("owner", str(uuid4()), ArtworkRequest(prompt="x"), 5, 50)
    repository.claim()
    Repository(config.data_dir).recover()
    assert repository.get_job("owner", job["id"])["status"] == "failed"


def test_queue_limit_and_invalid_image(setup):
    config, _ = setup
    repository = Repository(config.data_dir)
    from app.repository import CapacityError

    repository.create_job("owner", str(uuid4()), ArtworkRequest(prompt="x"), 5, 1)
    with pytest.raises(CapacityError):
        repository.create_job("owner", str(uuid4()), ArtworkRequest(prompt="x"), 5, 1)
    with pytest.raises(ProviderError):
        normalize_image(b"not an image", 100)
    with pytest.raises(ProviderError):
        normalize_image(b"a" * 101, 100)

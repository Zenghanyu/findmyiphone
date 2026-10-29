import asyncio
import base64
import io
import json
from dataclasses import replace

import httpx
import pytest
from PIL import Image

from app.config import Settings
from app.provider import HTTPImageProvider, ProviderError, normalize_image
from app.schemas import ArtworkRequest


def test_http_adapter_contract_and_normalization(tmp_path):
    output = io.BytesIO()
    Image.new("RGBA", (256, 256), (20, 40, 60, 255)).save(output, format="PNG")
    settings = Settings(
        data_dir=tmp_path,
        provider_url="https://image-provider.example/generate",
        provider_key="server-only-secret",
    )

    def respond(request):
        assert request.method == "POST"
        assert str(request.url) == settings.provider_url
        assert request.headers["Authorization"] == "Bearer server-only-secret"
        assert json.loads(request.content) == {"prompt": "山野", "width": 1024, "height": 1024}
        return httpx.Response(
            200, json={"image_base64": base64.b64encode(output.getvalue()).decode()}
        )

    provider = HTTPImageProvider(settings, transport=httpx.MockTransport(respond))
    data = asyncio.run(provider.generate(ArtworkRequest(prompt="山野")))
    result = normalize_image(data, settings.maximum_image_bytes)
    with Image.open(io.BytesIO(result)) as image:
        assert image.mode == "RGB"
        assert image.size == (256, 256)


@pytest.mark.parametrize(
    "response",
    [
        httpx.Response(500, text="server-only-secret"),
        httpx.Response(302, headers={"Location": "https://untrusted.example"}),
        httpx.Response(200, text="invalid json"),
        httpx.Response(200, json={"image_base64": "invalid base64!"}),
        httpx.Response(200, json={"other": "missing image"}),
        httpx.Response(200, json=[]),
    ],
)
def test_upstream_errors_are_safe(tmp_path, response):
    calls = []

    def respond(request):
        calls.append(request)
        return response

    provider = HTTPImageProvider(
        Settings(data_dir=tmp_path, provider_url="https://image-provider.example/generate"),
        transport=httpx.MockTransport(respond),
    )
    with pytest.raises(ProviderError) as failure:
        asyncio.run(provider.generate(ArtworkRequest(prompt="x")))
    assert "secret" not in str(failure.value)
    assert len(calls) == 1


def test_upstream_response_bound_and_timeout(tmp_path):
    settings = Settings(data_dir=tmp_path, provider_url="https://image-provider.example/generate")
    provider = HTTPImageProvider(
        replace(settings, maximum_image_bytes=5),
        transport=httpx.MockTransport(lambda _: httpx.Response(200, content=b"a" * 11)),
    )
    with pytest.raises(ProviderError, match="超过限制"):
        asyncio.run(provider.generate(ArtworkRequest(prompt="x")))

    def timeout(_):
        raise httpx.ReadTimeout("upstream-private-details")

    provider = HTTPImageProvider(settings, transport=httpx.MockTransport(timeout))
    with pytest.raises(ProviderError) as failure:
        asyncio.run(provider.generate(ArtworkRequest(prompt="x")))
    assert "upstream-private-details" not in str(failure.value)

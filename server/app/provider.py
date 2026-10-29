import base64
import binascii
import io
import json
from typing import Protocol

import httpx
from PIL import Image, UnidentifiedImageError

from .config import Settings
from .schemas import ArtworkRequest


class ImageProvider(Protocol):
    @property
    def configured(self) -> bool: ...

    async def generate(self, request: ArtworkRequest) -> bytes: ...


class ProviderError(Exception):
    """Contains only a user-safe message, never upstream bodies or credentials."""


def normalize_image(data: bytes, maximum_bytes: int) -> bytes:
    if not data or len(data) > maximum_bytes:
        raise ProviderError("图片为空或超过大小限制。")
    try:
        with Image.open(io.BytesIO(data)) as image:
            if image.width * image.height > 16_777_216:
                raise ProviderError("图片尺寸超过限制。")
            image.load()
            output = io.BytesIO()
            image.convert("RGB").save(output, format="PNG")
            result = output.getvalue()
            if len(result) > maximum_bytes:
                raise ProviderError("图片超过大小限制。")
            return result
    except (UnidentifiedImageError, OSError, Image.DecompressionBombError) as exc:
        raise ProviderError("生成服务返回了无效图片。") from exc


class HTTPImageProvider:
    """Vendor-neutral adapter: POST {prompt,width,height}, receive {image_base64}.

    The operator supplies a trusted server-side endpoint. No client-selected
    URLs or remote-image redirects are followed.
    """

    def __init__(self, settings: Settings, *, transport: httpx.AsyncBaseTransport | None = None):
        self.settings = settings
        self.transport = transport

    @property
    def configured(self) -> bool:
        return bool(self.settings.provider_url)

    async def generate(self, request: ArtworkRequest) -> bytes:
        headers = {}
        if self.settings.provider_key:
            headers["Authorization"] = f"Bearer {self.settings.provider_key}"
        try:
            async with httpx.AsyncClient(
                timeout=120, follow_redirects=False, transport=self.transport
            ) as client:
                async with client.stream(
                    "POST", self.settings.provider_url, json=request.model_dump(), headers=headers
                ) as response:
                    response.raise_for_status()
                    chunks = bytearray()
                    async for chunk in response.aiter_bytes():
                        chunks.extend(chunk)
                        if len(chunks) > self.settings.maximum_image_bytes * 2:
                            raise ProviderError("生成服务响应超过限制。")
                    payload = json.loads(chunks)
                    data = base64.b64decode(payload["image_base64"], validate=True)
        except (httpx.HTTPError, ValueError, KeyError, TypeError, binascii.Error) as exc:
            raise ProviderError("图片生成失败，请稍后重试。") from exc
        return data

import base64
import binascii
import io
from enum import StrEnum
from typing import Annotated
from uuid import UUID

from PIL import Image, UnidentifiedImageError
from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator

CleanText = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1)]


class ArtworkRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    prompt: Annotated[CleanText, Field(max_length=2000)]
    width: int = Field(default=1024, ge=256, le=2048)
    height: int = Field(default=1024, ge=256, le=2048)


class JobStatus(StrEnum):
    pending = "pending"
    running = "running"
    succeeded = "succeeded"
    failed = "failed"
    cancelled = "cancelled"


class ArtworkJob(BaseModel):
    id: UUID
    status: JobStatus
    error: str | None = None


class FeedbackAttachment(BaseModel):
    model_config = ConfigDict(extra="forbid")
    image_base64: str = Field(min_length=1, max_length=699_052)

    @field_validator("image_base64")
    @classmethod
    def validate_image(cls, value: str) -> str:
        try:
            data = base64.b64decode(value, validate=True)
            if not data or len(data) > 512 * 1024:
                raise ValueError("反馈图片不得超过 512 KiB。")
            with Image.open(io.BytesIO(data)) as image:
                if image.format not in {"JPEG", "PNG"} or max(image.size) > 1280:
                    raise ValueError("反馈图片需为最长边不超过 1280 像素的 JPEG 或 PNG。")
                image.load()
        except (
            binascii.Error,
            UnidentifiedImageError,
            OSError,
            Image.DecompressionBombError,
        ) as exc:
            raise ValueError("反馈图片无效。") from exc
        return value


class FeedbackRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    category: Annotated[CleanText, Field(max_length=50)]
    details: Annotated[CleanText, Field(max_length=5000)]
    contact: str = Field(default="", max_length=200)
    attachments: list[FeedbackAttachment] = Field(default_factory=list, max_length=10)


class Receipt(BaseModel):
    id: UUID

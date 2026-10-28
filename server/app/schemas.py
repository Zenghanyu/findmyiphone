from enum import StrEnum
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

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


class FeedbackRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    category: Annotated[CleanText, Field(max_length=50)]
    details: Annotated[CleanText, Field(max_length=5000)]
    contact: str = Field(default="", max_length=200)


class Receipt(BaseModel):
    id: UUID

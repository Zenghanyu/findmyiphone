import os
from dataclasses import dataclass, field
from pathlib import Path


@dataclass(frozen=True)
class Settings:
    data_dir: Path = field(default_factory=lambda: Path(os.getenv("EASYFIND_DATA_DIR", "./data")))
    api_tokens: tuple[str, ...] = field(
        default_factory=lambda: tuple(filter(None, os.getenv("EASYFIND_API_TOKENS", "").split(",")))
    )
    provider_url: str = field(default_factory=lambda: os.getenv("EASYFIND_IMAGE_PROVIDER_URL", ""))
    provider_key: str = field(default_factory=lambda: os.getenv("EASYFIND_IMAGE_PROVIDER_KEY", ""))
    maximum_pending_jobs: int = 50
    jobs_per_minute: int = 5
    feedback_per_minute: int = 10
    maximum_image_bytes: int = 15 * 1024 * 1024

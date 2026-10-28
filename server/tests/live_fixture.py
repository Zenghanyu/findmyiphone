"""Deterministic HTTP fixture for simulator integration; never used by the API factory."""

import os
from pathlib import Path

from app.config import Settings
from app.main import create_app
from tests.test_api import TestProvider


def fixture_app():
    return create_app(
        Settings(
            data_dir=Path(os.environ["EASYFIND_TEST_DATA_DIR"]),
            api_tokens=("integration-local-only",),
            jobs_per_minute=100,
        ),
        TestProvider(),
    )

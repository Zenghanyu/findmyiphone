import asyncio
import json
import logging
from contextlib import suppress

from .config import Settings
from .provider import ImageProvider, ProviderError, normalize_image
from .repository import Repository
from .schemas import ArtworkRequest

logger = logging.getLogger(__name__)


class ArtworkWorker:
    def __init__(self, repository: Repository, provider: ImageProvider, settings: Settings):
        self.repository = repository
        self.provider = provider
        self.settings = settings
        self.directory = settings.data_dir / "artworks"
        self.directory.mkdir(parents=True, exist_ok=True)
        self.wakeup = asyncio.Event()
        self.task: asyncio.Task | None = None

    def start(self):
        self.repository.recover()
        self.task = asyncio.create_task(self.run())

    async def stop(self):
        if self.task:
            self.task.cancel()
            with suppress(asyncio.CancelledError):
                await self.task

    async def run(self):
        while True:
            self.wakeup.clear()
            job = await asyncio.to_thread(self.repository.claim)
            if job:
                await self.process(job)
                continue
            try:
                await asyncio.wait_for(self.wakeup.wait(), timeout=1)
            except TimeoutError:
                pass

    async def process(self, job: dict):
        target = self.directory / f"{job['id']}.png"
        temporary = target.with_suffix(".tmp")
        try:
            raw = await self.provider.generate(ArtworkRequest(**json.loads(job["request"])))
            data = await asyncio.to_thread(normalize_image, raw, self.settings.maximum_image_bytes)
            await asyncio.to_thread(temporary.write_bytes, data)
            await asyncio.to_thread(temporary.replace, target)
            accepted = await asyncio.to_thread(self.repository.finish, job["id"], "succeeded")
            if not accepted:
                target.unlink(missing_ok=True)
        except asyncio.CancelledError:
            # A shutdown cannot leave a publicly visible successful job without a file.
            await asyncio.to_thread(
                self.repository.finish, job["id"], "failed", "服务正在重启，请重新提交。"
            )
            target.unlink(missing_ok=True)
            raise
        except Exception as exc:
            message = str(exc) if isinstance(exc, ProviderError) else "图片处理失败，请稍后重试。"
            logger.warning("artwork_job_failed id=%s kind=%s", job["id"], type(exc).__name__)
            await asyncio.to_thread(self.repository.finish, job["id"], "failed", message)
            target.unlink(missing_ok=True)
        finally:
            temporary.unlink(missing_ok=True)

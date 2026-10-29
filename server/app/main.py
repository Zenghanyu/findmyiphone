import hashlib
import hmac
from contextlib import asynccontextmanager
from typing import Annotated
from uuid import UUID

from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import FileResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .config import Settings
from .provider import HTTPImageProvider, ImageProvider
from .repository import CapacityError, ConflictError, Repository
from .schemas import ArtworkJob, ArtworkRequest, FeedbackRequest, Receipt
from .worker import ArtworkWorker


def create_app(settings: Settings | None = None, provider: ImageProvider | None = None) -> FastAPI:
    config = settings or Settings()
    repository = Repository(config.data_dir)
    image_provider = provider or HTTPImageProvider(config)
    worker = ArtworkWorker(repository, image_provider, config)

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        worker.start()
        yield
        await worker.stop()

    app = FastAPI(title="EasyFind API", version="0.1.0", lifespan=lifespan)
    bearer = HTTPBearer(auto_error=False)

    def authorize(credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(bearer)]):
        if not config.api_tokens:
            raise HTTPException(503, "服务尚未配置访问令牌。")
        if credentials is None or not any(
            hmac.compare_digest(credentials.credentials, token) for token in config.api_tokens
        ):
            raise HTTPException(401, "访问令牌无效。", headers={"WWW-Authenticate": "Bearer"})
        return hashlib.sha256(credentials.credentials.encode()).hexdigest()

    def find_job(owner: str, ident: UUID):
        job = repository.get_job(owner, str(ident))
        if not job:
            raise HTTPException(404, "未找到任务。")
        return job

    def capacity_error():
        return HTTPException(
            429, "请求过于频繁或队列已满，请稍后重试。", headers={"Retry-After": "60"}
        )

    @app.get("/health")
    def health():
        return {"status": "ok", "image_generation_configured": image_provider.configured}

    @app.post("/v1/artwork-jobs", response_model=ArtworkJob, status_code=202)
    def create_job(
        body: ArtworkRequest,
        owner: Annotated[str, Depends(authorize)],
        idempotency_key: Annotated[UUID, Header()],
    ):
        if not image_provider.configured:
            raise HTTPException(503, "尚未配置图片生成服务。")
        try:
            job = repository.create_job(
                owner,
                str(idempotency_key),
                body,
                config.jobs_per_minute,
                config.maximum_pending_jobs,
            )
        except ConflictError as exc:
            raise HTTPException(409, "此幂等键已用于不同的生成请求。") from exc
        except CapacityError as exc:
            raise capacity_error() from exc
        # Event.set belongs on the event loop, not this synchronous handler's thread.
        return ArtworkJob(**job)

    @app.get("/v1/artwork-jobs/{ident}", response_model=ArtworkJob)
    def get_job(ident: UUID, owner: Annotated[str, Depends(authorize)]):
        return ArtworkJob(**find_job(owner, ident))

    @app.delete("/v1/artwork-jobs/{ident}", response_model=ArtworkJob)
    def cancel_job(ident: UUID, owner: Annotated[str, Depends(authorize)]):
        find_job(owner, ident)
        repository.cancel(owner, str(ident))
        return ArtworkJob(**find_job(owner, ident))

    @app.get("/v1/artwork-jobs/{ident}/image", response_class=FileResponse)
    def get_image(ident: UUID, owner: Annotated[str, Depends(authorize)]):
        job = find_job(owner, ident)
        if job["status"] != "succeeded":
            raise HTTPException(409, "图片尚未生成成功。")
        path = worker.directory / f"{ident}.png"
        if not path.is_file():
            raise HTTPException(503, "图片文件暂不可用，请联系服务管理员。")
        return FileResponse(
            path, media_type="image/png", headers={"Cache-Control": "private, no-store"}
        )

    @app.post("/v1/feedback", response_model=Receipt, status_code=201)
    def feedback(body: FeedbackRequest, owner: Annotated[str, Depends(authorize)]):
        try:
            return Receipt(id=repository.feedback(owner, body, config.feedback_per_minute))
        except CapacityError as exc:
            raise capacity_error() from exc

    return app

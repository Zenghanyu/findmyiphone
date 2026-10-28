# EasyFind API

独立运行的 Python HTTP 服务，负责 AI 生图任务和反馈收集。设备连接、拍照延时、找手机、UWB、墨水屏编码与传输、提醒均在 iOS/配件端执行。界面通过 `EasyFindCore.ArtworkAPI` 调用本服务，不直接访问数据库或模型密钥。

## 本地启动

需要 Python 3.11+。从仓库根目录执行：

```sh
cd server
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.lock
python -m pip install --no-deps -e '.[dev]'
cp .env.example .env
```

在 `.env` 中填写配置；用 `python -c 'import secrets; print(secrets.token_urlsafe(32))'` 生成客户端令牌。配置文件不会自动读取，下面的命令将其导入当前 shell：

```sh
set -a
source .env
set +a
python -m uvicorn app.main:create_app --factory --host 127.0.0.1 --port 8000 --workers 1
```

模拟器中打开“设备 → 设置 → 后端服务设置”，地址填 `http://127.0.0.1:8000`，令牌填 `EASYFIND_API_TOKENS` 中的一项。真机的回环地址指向手机自身，真机联调应配置可访问的 HTTPS 地址。客户端只允许 HTTPS 或回环 HTTP。接口文档为本机 `/docs` 和 `/openapi.json`。

| 环境变量 | 用途 |
| --- | --- |
| `EASYFIND_DATA_DIR` | SQLite 与图片存储目录，默认当前目录下 `data/` |
| `EASYFIND_API_TOKENS` | 逗号分隔的客户端访问令牌；未配置时业务接口返回 503 |
| `EASYFIND_IMAGE_PROVIDER_URL` | 受信任的服务器端图片生成适配器地址；未配置时生图返回 503 |
| `EASYFIND_IMAGE_PROVIDER_KEY` | 适配器 Bearer 密钥，仅存于服务端 |

`requirements-dev.lock` 是本次 Python 3.12 验证环境的依赖版本快照，包含开发工具；依赖意图和兼容范围在 `pyproject.toml`。升级时同步更新快照并运行测试。

## 模型适配器

当前未绑定具体模型厂商。`HTTPImageProvider` 向管理员配置的固定 URL 发送：

```json
{"prompt":"山野插画","width":1024,"height":1024}
```

适配器返回 `{"image_base64":"<完整图片的 base64>"}`，可以附带其他字段。若设置了 `EASYFIND_IMAGE_PROVIDER_KEY`，请求携带 `Authorization: Bearer ...`。超时 120 秒，不跟随重定向，不读取客户端指定的图片 URL。服务端限制响应和图片大小，校验像素，解码并统一存为 RGB PNG。

可通过实现 `ImageProvider` 协议替换厂商调用，不改变 HTTP 路由或 SwiftUI 页面。适配器 URL 需实现上述契约，不能直接填写任意厂商的 API 地址。没有真实模型凭据时会明确报未配置；测试图片仅由 `tests/live_fixture.py` 注入。

## 接口

除 `/health` 外均需 `Authorization: Bearer <客户端令牌>`。每个令牌形成独立数据归属，数据库保存令牌的 SHA-256 摘要。此版采用人工配置令牌，尚无注册、登录或跨设备同步。

| 方法与路径 | 行为 |
| --- | --- |
| `GET /health` | 服务存活及生图适配器是否已配置 |
| `POST /v1/artwork-jobs` | 202 创建任务，必须提供 UUID 格式 `Idempotency-Key` |
| `GET /v1/artwork-jobs/{id}` | 查询 pending/running/succeeded/failed/cancelled 状态 |
| `DELETE /v1/artwork-jobs/{id}` | 取消未完成任务；已经成功或失败则保持终态 |
| `GET /v1/artwork-jobs/{id}/image` | 成功后下载受鉴权的 PNG；尚未成功返回 409 |
| `POST /v1/feedback` | `{category,details,contact}`，201 返回持久化的回执 ID |

同一令牌、同一幂等键、相同请求返回同一任务；同一键对应不同请求返回 409。取消防止结果发布，不保证上游已启动的计费请求会被撤销。任务失败或服务重启中断后需要新幂等键重新创建。图片不会作为公开静态目录暴露。

默认每个令牌每分钟最多 5 次新生图、10 次反馈，运行及待运行任务总数最多 50；限流返回 429 与 `Retry-After`。输入字段、UUID、图片尺寸及长度限制见 `schemas.py` 与 OpenAPI。

## 存储和运行边界

- SQLite WAL 和短事务支持请求并发，去重和任务领取均在事务内完成。单进程中运行一个后台 worker，**必须使用 `--workers 1`**；不要对同一数据目录启动多个服务实例。
- 重启后 pending 任务继续处理，遗留 running 任务转为明确失败。图片采用临时文件加原子替换，取消的结果不会转为成功。
- 模型错误不会透传上游响应或凭据；客户端收到稳定的中文错误。服务日志仅记录任务 ID 和异常类型。
- 数据目录包含反馈内容和图片，应由运行方持久保存及备份。首版没有自动清理、后台管理页面或用户删除接口；需按实际产品生命周期补齐归档策略。
- 对外运行时通过反向代理提供 HTTPS。账号、共享图库、付费和多进程队列属于后续独立扩展。

## 测试

```sh
python -m pytest tests -q
python -m ruff check .
python -m ruff format --check .
```

从仓库根目录执行 `scripts/test-backend.sh` 可同时验证服务端、Swift 核心、设备协议、图像转换和模拟器 HTTP 流程。使用其他 Python 环境时设置 `EASYFIND_TEST_PYTHON`，只跑主机测试可设置 `EASYFIND_SKIP_UI=1`。UI 测试使用 8001 端口和临时数据库，退出时清理；不会使用生产模型。

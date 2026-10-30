# SwiftUI 业务接入与后端架构

实现基线：`78df391`，工作分支 `codex/backend-integration`。原始范围分析见 [接入清单](backend-implementation-plan.md)。

## 分层与依赖

| 层 | 目录 | 职责 |
| --- | --- | --- |
| 界面 | `ios/EasyFindPrototype/EasyFind/*View.swift` | 输入、展示及导航，调用服务，不拼装 BLE 帧或 SQL |
| 应用服务 | `ios/EasyFindPrototype/EasyFind/Services/` | 可观察设备状态、通知调度、照片存储、API 配置与上传状态 |
| 纯业务与网络契约 | `ios/EasyFindCore/` | 提醒规划、API 协议/DTO/错误、原子 JSON 存储，可独立运行 Swift Package 测试 |
| 硬件适配 | 旧 `ios/EasyFind/Sources/` 及新 `Infrastructure/` | CoreBluetooth、AlarmKit、FindMyTagKit；Objective-C 门面隔离 BrushSDK |
| HTTP 后端 | `server/app/` | FastAPI 路由/鉴权 → SQLite repository → worker → ImageProvider |
| 配件 | `firmware/EasyFind-XIAO/` | 离线快门、可靠找手机投递、协议确认和延时持久化 |

iOS 与 HTTP 服务分别构建、运行和测试，通过版本化 `/v1` 接口联调。模型密钥不进入 App。设备操作无需绕行云端，也无需云端在线。

## 已实现的功能路径

- **遥控拍照**：接入原服务的读取/保存，等待匹配回执后更新界面；断连、忙和失败时不给出保存成功。离开编辑页仍保留原有草稿语义。
- **找手机**：App 生命周期启动蓝牙恢复服务，接入授权、开关、系统响铃状态与停止；复用可靠交付分支的请求 ID、有效期、重试、确认和持久去重。协议与固件需配套，详见 [可靠交付说明](phone-find-reliability.md)。
- **标签查找**：真实扫描、选取、测距回调和发声/停止，未连接和不支持 UWB 时显示可用性。
- **新版界面**：设备卡片、显示页纵向操作、提醒左滑删除、雷达、反馈附件及联系提示沿用新版 EasyFind-Frontend；外观（跟随系统/浅色/深色）、中英文和 App 设备显示名写入原子快照。新增快照字段可选，兼容现有数据。连接状态、电量可用性和业务结果来自原有服务。
- **画面**：实际相册和相机输入，ImageIO 按方向缩略到最长边 2048，限制输入 20 MiB；可拖动/缩放裁剪，由 `PhotoCropGeometry` 将显示区域映射到源像素，再由照片仓库在后台裁图。保留裁剪后的源像素供后续 DPID 处理，不提前缩成 240×240；图片写入 Application Support，重启可恢复。模板经 ImageRenderer 输出统一图像；前端已移除 AI 生图入口、路由和页面，服务端生成 API 与网络契约保留。
- **墨水屏**：明确选择 HINK-T0154A10-A2 240×240 六色普通 BLE 设备，规格 3/4；选图后在后台执行居中裁剪、DPID 降采样和六色抖动，首页与上传确认页均可切换原图/六色效果，不依赖设备绑定或连接。`InkArtworkController` 缓存同一次处理生成的预览和不可变码流，换图或切换规格后重新处理，并丢弃迟到结果；`InkTransferController` 只在用户确认后传输缓存数据，不再二次量化。显示实际数据包进度，支持超时和取消。SDK 刷新命令被接受后展示“设备已接收，请等待屏幕刷新”，尚无实屏完成传感确认。预览使用面板标称色彩，不能代替实物校色。
- **提醒与报时**：系统通知授权、每天/工作日/具体日期一次性提醒、开关和删除撤销、规则修改重排。归属前缀隔离其他通知，计算 iOS 64 条待处理容量，失败回滚。每天/工作日随本地时区，每个一次性提醒保存绝对日期。报时由手机通知执行。
- **反馈与保留的生成服务**：App 配置独立服务地址与 Keychain 令牌，反馈等待持久化回执。服务端保留生成任务的创建、查询、下载与取消接口及幂等处理，App 不再提供生成操作。反馈照片在照片仓库中压缩到最长边 1280 像素、每张最多 512 KiB，最多 10 张，API 再独立校验并与正文一起持久化到 SQLite。生成图片经校验后原子落盘。

## 数据与扩展约束

`AppModel` 作为依赖组装入口，快照存入 `settings-v2.json`；首次读取旧 `easyfind.native.v1`，迁移单次提醒的日期并保存。图片单独存文件。数据损坏时保留原文件并报错，禁止静默覆盖。

更换模型服务实现 `ImageProvider`，更换 HTTP 客户端实现 `ArtworkAPI`，更换墨水屏协议在 `EFInkBridge` 和 `InkTransferController` 后面适配。不要把供应商 SDK 直接引入页面。`Vendor/BrushSDK` 保留上游结构与修改说明，避免与业务代码混放。

FindMyTag 标签、XIAO 遥控器、BrushSDK 墨水屏是三种不同协议设备，目前分别选择和连接；首页连接状态对应遥控器。未在协议中获得的电量与版本不再显示伪造数据。

SQLite 首版仅允许单服务进程。增加账号、多实例或多任务并行时，先引入正式身份模型、版本化迁移与外部任务队列；不要直接增加 Uvicorn workers。访问令牌轮换会改变数据归属，目前需要保留旧令牌访问旧任务。

## 验证方法

本轮环境、测试结果与真实设备待验收范围见 [软件验证记录](backend-validation.md)。

从根目录执行：

```sh
EASYFIND_TEST_PYTHON=/path/to/python scripts/test-backend.sh
```

脚本包含 API/worker/鉴权/幂等/取消/恢复/限流/上游异常测试、Swift 提醒与 API 测试、C++ 固件协议与可靠交付测试、Swift 去重与持久化测试、C 图像码流测试，并构建安装 App、运行 XCUITest。App 端到端测试通过实际回环 HTTP 提交反馈，并验证中英文模板页不提供 AI 生图入口；生成服务由 API/provider/worker 和 Swift 网络契约测试覆盖，确定性 provider 只在测试工厂注入。UI 中的蓝牙演示也只在模拟器显式参数下启用。测试快照、照片、API 偏好和 Keychain 账号使用独立空间；模拟器 App 采用本地签名以验证真实 Keychain 写入，无需开发者证书。

Xcode 的 `generic/platform=iOS` 无签名编译检查设备切片兼容性；它不替代设备安装与硬件联调。第三方 BrushSDK 仍有上游 Objective-C 隐式捕获 self 的编译警告，业务 Swift 代码不依赖关闭这些检查。

## 后续验收边界

真实模型尚需填写服务方契约和凭据。UWB、后台恢复/AlarmKit、通知实际送达、真实拍照及墨水屏刷新均需目标 iPhone 和配件联调。墨水屏型号是当前默认支持配置，其他面板应新增明确适配。当前测试不代表已完成这些真机验收；旧版真机记录见 [硬件验证记录](hardware-validation.md)。

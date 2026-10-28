# SwiftUI 前端的功能接入与后端实现清单

检查日期：2026-10-26。前端基线：`feat/swiftui-frontend-controls` / `78df391`。

> 本文保留接入前的分析记录。2026-10-27 起的已实现功能、目录边界和验收范围见 [后端架构](backend-architecture.md)，服务运行方法见 [API 说明](../server/README.md)。下文“尚未实现”等描述均指原始前端基线。

## 结论与代码边界

目前前端是独立的 SwiftUI 原型。`AppModel` 将设置和提醒编码到 UserDefaults；相册能读取照片，但照片只保留在当前会话。连接、电量、测距、响铃、拍照入口、AI 和上传进度含演示逻辑。

主要工作分为 iOS 本地业务层、设备协议/固件、可选云端服务。拍照、找手机、UWB、墨水屏刷图和本地提醒主要由手机与设备直接完成；云端主要服务于 AI 生图。反馈后台、账号及同步可以按产品需要追加。当前分支没有独立 Web 服务或 HTTP API 客户端。

已有代码分散在三个来源，尚未统一接入这个 SwiftUI target：

| 来源 | 可复用内容 | 当前状态与边界 |
| --- | --- | --- |
| 当前分支 `ios/EasyFind` | CoreBluetooth、FindMyTagKit、UWB 会话、设备发声、遥控拍照配置、AlarmKit 找手机 | 原硬件版 App；不是 SwiftUI 原型的依赖。仓库记录了部分旧版本拍照/找手机真机验证，不能代替新 UI 接入验收 |
| `feat/reliable-background-phone-find` / `67ca70a` | BLE 后台恢复、找手机请求 ID、30 秒有效期、重试、确认及去重 | 本地与 `fork` 都保留此分支；扩展需要 App 与固件配套更新，长期后台尚待真机验收 |
| `fork/feat/ink-screen-app-dpid` / `8b55b44` | 独立 `ink-screen-app`，BrushSDK、BLE/NFC 刷图、设备信息、图片裁剪、DPID 降采样、六色量化 | 尚未合入当前工作区；分支 README 明确其算法检查不等于 iOS 编译或真实刷屏已验证 |

`codex/testflight-testing` 在后台找手机改进之上另有签名/分发配置。功能集成应优先评估 `67ca70a`，分别审查工程配置，避免顺带引入无关签名设置。本次只检查，未合并这些分支。

## 逐页需要实现的功能

| 功能 | 前端现状 | 实现内容 | 优先级 |
| --- | --- | --- | --- |
| 设备接入与信息 | “已连接”、86% 电量、设备名称及固件版本为固定值 | 真实设备身份、能力、连接/重连/错误状态、电量与版本；无设备或未授权时的操作限制 | P0 |
| 遥控拍照 | 保存仅更新本机 `photoDelaySeconds` | 接入 `SelfieStickService.save(delay:)`，先读取设备配置，等待设备持久化确认后更新 UI；处理忙、超时、存储失败 | P0 |
| 反向找手机 | 开关仅保存本机偏好，“随时待命”为固定展示 | 连接及后台订阅、AlarmKit 授权/状态/停止、旧 iOS 通知兼容、禁用语义；优先复用可靠交付分支 | P0 |
| 查找设备与发声 | 固定 2.4 米/右前方；发声只弹提示 | 接入标签扫描、BLE 连接、`TagRangingService` 和 SDK 测距回调；发声/停止；无 UWB、方向丢失、断连及权限状态 | P1 |
| 相册与拍照 | 相册能读图；拍照实际显示模板选择 | 实际摄像头、权限、原始像素裁剪/旋转、EXIF 方向、输入尺寸限制、照片本地持久化；统一选图数据模型 | P1 |
| 图片处理与模板 | SwiftUI 绘制的三套模板，照片只是视觉裁切 | 根据面板规格渲染模板与照片；适配分辨率、色板、方向、量化/抖动；区分预览图和传输数据 | P1 |
| 上传到墨水屏 | 每 120ms 增加 10% 的模拟进度 | Swift/Objective-C 桥接 BrushSDK、匹配目标设备、编码与分包、真实进度、失败/取消、设备完成确认 | P1 |
| 事项提醒 | 增删改、开关与重复规则已本机保存，无调度 | 通知授权、每天/工作日/仅一次调度、关闭/删除时撤销、编辑后替换、时区变化处理 | P1 |
| 自动报时 | 只保存开始/结束时间和间隔 | 明确由手机通知还是设备发声；手机端安排周期通知，设备端则需时间同步、规则写入及固件计时 | P1 |
| AI 生图 | 根据关键词返回已有模板 | 云端生成服务、任务状态、错误/重试、结果下载及进入图片处理链路 | P2 |
| 意见反馈 | `ShareLink` 分享文本，未提交后台 | 如需集中收集，增加反馈 API、工单号和提交状态；也可继续采用现有分享流程 | P2 / 可选 |
| 账号与同步 | 无登录、账号、跨端同步页面 | 仅在需要跨设备同步、云端图库或付费配额时加入身份与同步服务 | 后续 / 可选 |

P0 是优先闭环；P1 可按设备类型安排。墨水屏是主要验收目标时，可将刷图接入提前，与遥控拍照/找手机并行规划。

## 可直接复用的入口

- [SelfieStickService.swift](../ios/EasyFind/Sources/SelfieStick/SelfieStickService.swift)：读取/保存延时、响铃开关、AlarmKit/通知及业务状态。
- [SelfieStickBluetoothTransport.swift](../ios/EasyFind/Sources/SelfieStick/SelfieStickBluetoothTransport.swift)：检索系统已连接设备、App 自身连接、订阅和恢复。
- [SelfieStickProtocol.swift](../ios/EasyFind/Sources/SelfieStick/SelfieStickProtocol.swift)：帧、事务号、能力检查和设备确认。
- [TagScanner.swift](../ios/EasyFind/Sources/Services/TagScanner.swift)、[TagRangingService.swift](../ios/EasyFind/Sources/Services/TagRangingService.swift)：标签发现、UWB 生命周期、距离/方向回调、发声和停止。SDK 另有 `requestBattery(completion:)`。
- [PermissionManager.swift](../ios/EasyFind/Sources/Services/PermissionManager.swift)、[原工程 Info.plist](../ios/EasyFind/Info.plist)：权限及后台模式参考。
- [当前固件](../firmware/EasyFind-XIAO/src/main.cpp)、[配置协议](selfie-stick-protocol-v0.1.md)：BLE HID、自定义延时配置和找手机事件。
- [墨水屏分支](https://github.com/asfigh665/findmyiphone/tree/8b55b44/ink-screen-app)：`XTBleWriteHelper` 处理刷图和设备信息；`XTPhotoResampler` / `XTInkPhotoProcessor` 处理照片与六色色码。需要桥接和 target 依赖配置。

旧服务主要通过 `onChange`/闭包暴露状态；建议增加 SwiftUI 可观察适配层，不在各页面分别持有蓝牙 manager 或创建重复会话。

## 必须先明确的硬件与产品条件

1. **目标设备是否为同一个配件。** 当前 XIAO ESP32S3 固件只实现自拍杆配置/HID/找手机，未实现 UWB、墨水屏驱动或蜂鸣器控制。FindMyTag 标签、XIAO 遥控器和 BrushSDK 墨水屏采用不同协议，需按设备标识与能力关联，不能仅凭相同显示名称视为同一台设备。
2. **墨水屏型号与接入方式。** DPID 六色链路针对 HINK-T0154A10-A2 240×240 的指定 BLE 路径；其他屏幕或 NFC 路径需采用各自配置。若实际设备兼容 BrushSDK，应先复用；自研设备则需与固件约定传输和刷屏协议。
3. **报时/事项的执行位置。** 手机本地通知可以独立实现；如果希望手机离线或不在附近时随身屏仍提醒，必须让设备保存规则并具备计时、时钟同步和提示硬件。云端服务无法替代这些设备能力。
4. **单次提醒日期与时区。** 现在 `ReminderItem` 只有 `HH:mm` 与展示字符串，无法完整表示“仅一次”的日期或时区。应采用结构化重复规则、具体触发日期及明确的时区策略。

## 接入时应保持的行为约束

- 遥控拍照先由用户在系统蓝牙完成 HID 配对；App 检索并接入已连接的配置服务。标签或墨水屏的扫描流程另按各自协议处理。
- 本机设置值不代表设备已保存。收到匹配事务号、成功状态及一致回显后，才显示延时保存成功；未知结果需重新读取。
- 自拍倒计时和 HID 按键由设备执行，系统相机需已打开；App 不再额外计时或补发快门。
- 找手机服务应由 App 生命周期持有，支持无界面时恢复；不能只在页面出现时初始化。iOS 26+ 的 AlarmKit 需单独授权，低版本采用通知兼容路径。
- 墨水屏进度反映真实传输状态；发送完数据与设备完成刷新应分别处理。预览图与上传码流由同一处理结果生成，不能把视觉预览重新取色当作协议负载。
- 事项保存/开关改变后同步更新系统任务，删除时取消对应任务。较多事项需考虑系统待处理通知上限和重复规则合并，避免只安排有限天数后无补排机制。
- 真机集成前端时补齐实际使用的蓝牙、Nearby Interaction、相机、AlarmKit、后台模式及按需 NFC 能力。当前 SwiftUI 工程最低 iOS 17，新增 API 需版本检查。

## 建议的服务拆分

以下是建议接口边界，尚未实现：

| 模块 | 职责与输出 |
| --- | --- |
| `DeviceStore` | 当前设备、协议身份映射、能力、连接、电量和版本；不可用原因 |
| `RemoteControlService` | 读取/确认保存拍照延时；适配旧自拍杆服务 |
| `PhoneFindingService` | 偏好、授权、蓝牙事件与可靠去重、系统闹钟状态 |
| `RangingService` | 真实距离/方向、会话状态、发声/停止；适配 FindMyTagKit |
| `ArtworkRepository` / `ImageProcessingService` | 原图、模板、处理参数、面板配置、预览与设备数据；本地文件引用 |
| `InkTransferService` | 准备、连接、传输、刷新、完成、失败/取消；适配 BrushSDK |
| `ReminderRepository` / `ReminderScheduler` | 结构化提醒数据及系统通知的创建、替换与撤销 |
| `AIArtworkClient` / `FeedbackClient` | 云端任务及按需反馈提交；与设备 BLE 链路分离 |

`AppModel` 可继续管理 UI 选择状态；设备事实、图片二进制与提醒调度状态由服务提供。当前 UserDefaults 快照可迁移到有版本的数据存储；图片采用文件存储，避免把大图放进偏好设置。

## 如需云端，第一版的最小范围

以下 API 仅为规划，仓库中尚不存在，也未绑定技术栈或服务商：

| API | 用途 |
| --- | --- |
| `POST /v1/artwork-jobs` | 提交描述、目标尺寸/屏幕配置和幂等键，返回任务 ID |
| `GET /v1/artwork-jobs/{id}` | 获取 pending/running/succeeded/failed 状态、结果地址和失败原因 |
| `POST /v1/feedback` | 可选：反馈类型、内容、选填联系方式及经用户同意附带的诊断信息 |
| `GET /v1/templates` | 可选：远程模板列表；首版可继续使用本地模板 |

云端负责模型调用凭证、调用配额/限流、任务执行和结果存储；客户端负责下载与实际面板适配。若产品需要云端保存图片、账号或提醒，再增加身份、数据同步及删除接口。本地设备控制无需为每个动作设计 HTTP 接口。

## 建议的实现顺序与验收

1. **统一工程和设备状态。** 将旧服务作为共享模块/源码依赖接入 SwiftUI，配置权限与生命周期；让首页按真实连接状态显示，明确每种硬件支持哪些操作。
2. **完成已有硬件功能闭环。** 接入拍照配置、找手机，并评估 `67ca70a` 的 App/固件配套改进；验收保存确认、重启读回、退出 App 后拍照、锁屏响铃、关闭开关及重复请求。
3. **接入墨水屏与查找。** 对墨水屏分支做 Mac 构建与依赖检查，封装图片处理及 BLE 传输；在目标标签上验证 UWB 和设备发声。两条硬件链路分别验收。
4. **实现本地提醒。** 补齐日期/时区模型和真实通知，覆盖增删改、开关、工作日、单次触发及自动报时。
5. **接入 AI 与可选反馈服务。** 生图结果复用已有图片处理和上传链路；验证失败、取消、重试与重复提交。

本次前端预览的模拟器构建、交互测试和截图只能证明 UI 可运行。旧版真机记录见 [hardware-validation.md](hardware-validation.md)；可靠找手机分支和墨水屏分支的硬件验收仍应分别完成。

## 本次前端预览验证

- Xcode 27.1 / iPhone 17 Pro / iOS 26.5 模拟器：`EasyFindPrototype` Debug 构建通过，App 安装与启动通过。
- 现有 `ButtonReview` 的 2 个测试用例通过，0 失败。覆盖页面导航、拍照草稿/保存、手机响铃开关、上传演示、提醒空标题校验、开关点击及双向拖动。
- [三个主页面截图](../outputs/frontend-preview-20261026/frontend-preview.png)来自本次模拟器运行；[测试结果](../outputs/frontend-preview-20261026/ButtonReview.xcresult)保留在本机忽略目录 `outputs/` 中，不随 Git 提交。
- 本次新增此分析文档，未修改前端业务代码，也未实现云端或合并其他功能分支。

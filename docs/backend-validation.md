# 后端集成软件验证记录

日期：2026-10-28。分支 `codex/backend-integration`，前端基线 `78df391`。本记录覆盖本机软件与模拟器；旧版本真机记录见 [hardware-validation.md](hardware-validation.md)。

## 环境与命令

- Xcode 27.1，iPhone 17 Pro / iOS 26.5 模拟器。
- Python 3.12，依赖快照为 `server/requirements-dev.lock`。
- `EASYFIND_TEST_PYTHON=/path/to/python scripts/test-backend.sh` 运行完整回归。App 与 UI runner 使用模拟器本地签名，不需要开发者证书；设备 SDK 使用 `CODE_SIGNING_ALLOWED=NO` 单独编译。
- 固件仅执行 PlatformIO `run`，没有上传到开发板。

## 结果

| 验证项 | 结果与覆盖 |
| --- | --- |
| Python API / worker / provider | 16 项通过；鉴权与归属隔离、并发幂等/冲突、实际 worker 图片输出、取消不转成功、重启恢复、反馈持久化/限流、上游契约/超时/重定向/错误与响应大小 |
| Swift EasyFindCore | 10 项通过；提醒日期/时间/工作日/容量、原子存储和损坏报错、HTTP 认证/幂等/错误/路径校验 |
| XCUITest | 4 项通过、0 失败；页面导航/草稿与保存、开关点击/双向拖动、真实 HTTP 生图与反馈/照片重启恢复、未连接设备禁止保存 |
| C++ 协议与可靠交付 | 主机测试通过；金帧、无效请求、配置边界、TTL、重试、ACK、去重、重连与时钟回绕 |
| Swift 找手机交付 | 主机测试通过；协议兼容、确认时机、并发去重、持久重放、过期与写入失败 |
| C 图像处理 | 5 组通过；DPID 常量白图、白色色码、六色标记、无效输入/尺寸、原图裁剪 |
| iOS 编译 | 模拟器与 generic iOS 设备 SDK 均通过；设备构建不签名、不安装 |
| ESP32S3 固件构建 | PlatformIO 构建成功，未烧录 |
| 静态检查 | Ruff、Swift Format、`git diff --check`、工程/Info.plist 与 shell 语法检查通过 |

本轮完整产物目录为 [outputs/backend-tests-20261028-001709](../outputs/backend-tests-20261028-001709/)，本机保留 `build.log`、`ui.log`、`ui.xcresult` 和 HTTP fixture 的 `api.log`。产物在 Git 忽略目录中，其他机器可用上述命令重新生成。

截图：[正常运行预览](../outputs/backend-tests-20261028-001709/preview.png)、[HTTP 返回的测试图片](../outputs/backend-tests-20261028-001709/backend-generated-image.png)、[反馈回执](../outputs/backend-tests-20261028-001709/backend-feedback-receipt.png)。预览使用正常启动参数，显示真实的未连接状态。

HTTP 场景通过实际回环请求完成创建、轮询、下载及反馈提交，重启 App 后验证照片恢复；生图 provider 为独立测试工厂注入的确定性图片。业务接口和网络传输并未用 UI 假成功替代。测试使用单独快照、照片、API 偏好与 Keychain 账号，退出时停止 fixture 并删除临时数据库。

## 实物和外部服务待验收

以下没有在本轮作为通过项：

- 真实模型服务的凭据、供应商契约与生成效果；生产工厂没有配置 provider 时返回明确的 503。
- 新 UI 与遥控器的配置确认、离线拍照、后台蓝牙恢复、锁屏 AlarmKit 及长期后台交付。
- 目标 FindMyTag 标签的实际 UWB 距离/方向及发声。
- HINK 240×240 六色规格 3/4 的真实 BLE 刷图、断线/取消与实屏效果；软件成功表示 SDK 接受刷新指令。
- 目标 iPhone 的相机和通知实际送达、权限变化及各系统模式。

实现边界见 [后端架构](backend-architecture.md)，运行与接口契约见 [服务端说明](../server/README.md)。

## 2026-10-28：补齐上传前六色预览

原实现只在用户点击“确认上传”后执行 DPID/六色转换并显示结果，选图页及确认前显示原图。现已拆分本地处理与 BLE 发送：选图页和确认页自动显示 240×240 六色效果，可切换原图；不需要绑定或连接设备。不可变处理结果同时保存预览与协议数据，发送不再重复处理。换图或更换规格后重新计算，迟到的处理结果不会覆盖新图。设备绑定的测试偏好也已与正常运行隔离。

完整回归命令与前述相同。本轮 API 16 项、Swift Package 10 项、协议/可靠交付检查与 C 图像处理 5 组均通过；XCUITest 为 **5 项通过、0 失败**，新增未绑定设备时的真实预览、原图切换、禁止发送及换模板重算，HTTP 测试另验证下载图片在重启后的六色预览。模拟器及 generic iOS 设备 SDK 编译、Swift Format 和 `git diff --check` 通过。已检查截图，预览、切换控件与确认按钮可见。

产物目录：[outputs/backend-tests-20261028-123923](../outputs/backend-tests-20261028-123923/)，包含 `checks.log`、`build.log`、`device-build.log`、`ui.log`、`ui.xcresult`、`api.log` 与截图。

- [模板的六色效果](../outputs/backend-tests-20261028-123923/ink-new-template-preview.png)
- [未绑定设备的上传前预览](../outputs/backend-tests-20261028-123923/ink-preview-without-device.png)
- [导入图片重启后的六色预览](../outputs/backend-tests-20261028-123923/ink-imported-image-preview.png)

图片处理走真实本地算法；HTTP 生图仍使用确定性测试 provider，演示上传不作为 BLE 验收。标称面板色彩预览不代替实屏校色，物理传输与刷新仍需 HINK 设备验收。

## 2026-10-29：新版前端接入

在 `codex/frontend-refresh` 中将新版 EasyFind-Frontend 的布局接入现有 App 工程，保留生命周期、硬件适配、本地持久化与独立 HTTP 服务。设置新增中英文、外观和 App 设备显示名；旧快照可继续读取。相册和拍照新增源像素裁剪，再由原 DPID/六色流程生成预览及对应码流。AI 生图位于模板页工具栏。反馈附件通过真实 API 校验并持久化，成功页展示回执编号。

主机验证为 API **23 项通过**、Swift 核心 **15 项通过**，覆盖附件鉴权/持久化、非法编码/格式/尺寸/大小/数量拒绝、客户端附件契约，以及横竖图、平移、缩放、越界和无效裁剪参数。既有 C/C++/Swift 协议及 C 图像处理检查继续通过。模拟器与 generic iOS 设备 SDK 编译通过，设备构建不签名、不安装。

图片缩放后已核对模拟器仓库中的实际 JPEG，保存的是方形源像素裁剪结果，重启后重新生成 240×240 六色预览。界面截图检查了设备、显示、提醒、深色英文设置和裁剪页。截图中的 UI 演示连接状态不作为配件验收；物理配件、真实相机和通知实际送达沿用上文待验收范围。

XCUITest 的 **7 个用例最终均通过**，包含页面导航/设置确认、主题/语言/名称持久化、真实 HTTP 生图/裁剪/反馈回执、无设备预览/禁止发送、提醒开关/左滑删除/重启保存、系统相机打开与取消、未连接设备禁止保存。修复了删除时读取已失效数组绑定而崩溃的问题，提醒行现在按稳定 ID 更新；另修复旧照片在设备卡片中超出边框。当前模拟器报告相机可用，因此实际验证的是系统取景器打开与取消，实拍仍待目标设备验收。

产物在 [outputs/frontend-refresh](../outputs/frontend-refresh/)：主回归记录见 [outputs/backend-tests-20261029-000813](../outputs/backend-tests-20261029-000813/)，提醒/相机的最终定向回归为 `verified-ui.xcresult`（1 项通过），正常启动及图片边界复测为 `final-ui.xcresult` 中的 `testUnavailableDeviceCannotSaveSettings`（通过）。`build.log`、`device-build.log` 与 `checks.log` 保存编译及主机检查结果。Ruff、Swift Format、工程/Info.plist、shell 语法和 `git diff --check` 均通过。

- [正常启动的新版三页预览](../outputs/frontend-refresh/preview.png)
- [深色英文设置](../outputs/frontend-refresh/settings-dark-english.png)
- [照片裁剪](../outputs/frontend-refresh/photo-crop-new.png)
- [服务端反馈回执](../outputs/frontend-refresh/backend-feedback-receipt.png)


## 2026-10-30：移除前端 AI 生图入口

基于远端 `main` 的 `e2ab72d`，删除模板页 AI 生图按钮、`InkRoute.ai`、`AIArtworkView` 和未再使用的前端生成状态。服务端生成 API、provider/worker 及 Swift 网络契约保留；服务设置继续用于反馈，界面文案同步调整。

- API/provider/worker：23 项通过；Swift Core：15 项通过；既有设备协议与图像核心检查通过。
- 模拟器编译通过，修改的 Swift 文件通过 Swift Format 严格检查。
- `testHTTPFeedback` 通过真实回环 HTTP 验证反馈回执，记录位于 `outputs/backend-tests-20261030-144726/ui.xcresult`。
- `testAppearanceLanguageAndDeviceNamePersist` 与 `testInkPreviewBeforeUploadWithoutDevice` 最终均通过，覆盖中英文模板页无 AI 入口、主题/语言持久化、模板切换、240×240 预览及未绑定设备禁止上传，记录位于 `outputs/remove-ai-entry-verified-ui.xcresult`。

首次定向 UI 运行中，新增测试步骤在切回设备标签后重复点击已保留的设置页，导致该用例中断并使下一项继承英文状态；修正脚本导航并恢复独立 UI 测试空间的中文初始状态后，两项复测通过。本轮不再通过 AI 生成图片准备裁剪/照片重启场景，该历史 UI 用例覆盖已移除；源像素裁剪几何仍由 Swift Core 测试覆盖，照片导入与实拍验收边界不变。

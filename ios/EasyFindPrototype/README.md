# EasyFind SwiftUI 集成入口

黑白风格 iPhone App，包含设备、显示、提醒页面。已合入新版 EasyFind-Frontend 的卡片布局、裁剪流程、主题、语言及反馈界面。界面与业务服务分离，后端 HTTP 服务独立运行。设计与验收范围见 [后端架构](../../docs/backend-architecture.md)。

## 运行与服务配置

1. 打开本目录 `EasyFind.xcodeproj`，选择 `EasyFind` scheme，最低 iOS 17。
2. 选择 iPhone 模拟器，按 ⌘R 运行；真机需选择自己的签名 Team/Bundle ID。当前 Bundle Identifier 为 `com.easyfind.companion`。FindMyTagKit 设备切片需 Xcode 27 或兼容工具链。
3. 依赖为本地 `../EasyFindCore` 包、共享硬件源文件、FindMyTagKit 和 BrushSDK，已在工程中配置。
4. 反馈需按 [服务端说明](../../server/README.md) 启动 API，再于“设备 → 设置 → 后端服务设置”填写地址和客户端令牌。模拟器可用 `http://127.0.0.1:8000`，真机使用可访问的 HTTPS。

正常运行时显示实际连接状态；没有配件时不能保存拍照配置或传输画面。相机入口按系统报告的能力打开取景器或提示不可用，实际拍摄需目标设备验收。仅 UI 测试显式使用 `-uiMock -selfieDemo -phoneFindAuthorized` 开启设备演示；这些参数不代表蓝牙、UWB 或实屏验收。

## 功能与存储

- 遥控拍照设置等待设备确认，找手机接入系统授权/停止和后台服务。设备需先在系统蓝牙配对。
- UWB 扫描和真实测距由 FindMyTagKit 适配。标签与遥控器分别连接。
- 相册和实际拍照先进入可拖动、缩放的方形裁剪页，再保存图片。裁剪保留输入细节，不先缩小到 240 像素；DPID 和六色抖动在预览阶段执行。模板为本地绘制；前端不提供 AI 生图入口或页面，服务端生成接口仍保留。墨水屏绑定支持 HINK-T0154A10-A2 240×240 六色普通 BLE 规格 3/4；刷新命令被接受后提示等待实屏刷新。
- 选图后自动生成 240×240 屏幕实际展示预览；未连接墨水屏也能预览。上传直接复用预览对应的处理数据，未绑定设备时禁止发送。已导入照片可用显示页右上角裁剪按钮继续调整；预览使用标称面板色彩，实物效果需真屏核对。
- 设置提供浅色、深色、跟随系统及中英文切换，并持久保存。设备名称编辑只修改 App 中的显示名，不写入配件固件。
- 反馈支持最多 10 张图片和可选联系方式，图片在本地压缩为最长边 1280 像素、每张最多 512 KiB，再提交到独立 API；只有收到服务端持久化回执才显示成功。
- 每天、工作日、具体日期的单次提醒，以及指定时段报时均由手机系统通知执行。需要允许通知，并受系统容量及送达策略约束。
- 设置与规则原子写入 Application Support，兼容旧 UserDefaults 迁移；图片另存文件。访问令牌保存在 Keychain，模型密钥只放服务端。

设备按键后台交付、UWB、墨水屏和通知实际送达需真机与配件验收。本次模拟器测试及无签名设备构建不代替该验收。

## 构建和回归

在仓库根目录执行：

```sh
EASYFIND_TEST_PYTHON=/path/to/server-venv/bin/python scripts/test-backend.sh
```

脚本构建/安装 App 并启动独立 XCUITest 工程。测试覆盖导航、开关、设置确认、未连接设备保护、未绑定设备的真实屏幕预览与模板更换，以及主题/语言/名称持久化、通知授权提示中英文切换及重启恢复、左滑删除、系统相机打开/取消或不可用提示、中英文模板页无 AI 入口、真实回环 HTTP 反馈回执。测试中的图片处理走真实算法；仅 BLE 发送可以模拟，`-uiMock -inkUseBluetooth` 保留独立存储并使用真实发送可用性检查。HTTP fixture 使用临时数据库和 8001 端口，退出时清理；日志及 xcresult 在 `outputs/backend-tests-*`。

单独编译可执行：

```sh
xcodebuild -project ios/EasyFindPrototype/EasyFind.xcodeproj -scheme EasyFind -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/easyfind-build CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
```

原前端 [主页面预览](docs/easyfind-buttons-preview.png) 与 [开关状态](docs/easyfind-toggle-states.png) 保留为外观参考；设备与业务状态以当前运行结果为准。

# EasyFind / findmyiphone

在 FindMyTag SDK v1.4.3 示例工程上开发的 iOS App 与 XIAO ESP32S3 测试固件。

App 包含两个窗口：**查找**（原标签查找功能）与 **功能**（远程拍照、查找我的手机）。

- **远程拍照**：App 将 0–30 秒延时保存到设备。设备按键触发倒计时，发送 BLE HID 音量键；系统相机需已打开，日常拍照不依赖 EasyFind 运行。
- **查找我的手机**：长按设备 BOOT，App 后台接收 BLE 事件。iOS 26 起使用 AlarmKit，首次需允许系统闹钟，收到请求约 2 秒后由系统响铃，可从锁屏停止。旧系统保留通知方式。新版固件暂存请求最多 30 秒，等待蓝牙恢复并重试；新版 App 在系统接受后确认，并保存处理记录以避免重复响铃。
- **长期后台**：使用 Core Bluetooth 状态恢复、通知订阅与系统管理的待重连任务，目标是首次配置后长期无需打开 App。用户上划强退、蓝牙关闭、手机关机或超距期间不能保证触发；30 秒有效期后不补响。

## 当前验证状态

2026-10-12，旧版在 iPhone 15 Pro Max / iOS 26.5 与 Seeed XIAO ESP32S3 Sense 上验证：系统配对、App 保存 5 秒后离开 App 使用系统相机拍照、锁屏系统闹钟、静音响铃、停止及再次触发。相关客户端回归 4 项通过。

2026-10-18 的改造包括 App 蓝牙恢复、串行写入与请求确认，以及固件缓存、重试和过期机制。本轮未烧录硬件；旧版验收不代表新版已经完成真机验证。24 小时、72 小时、7 天后台、重启恢复、专注模式、Android 及原标签 UWB 功能均需单独验收。详见 [可靠性改造与长测计划](docs/phone-find-reliability.md) 和 [真机验证记录](docs/hardware-validation.md)。

## 开发入口

1. 打开 `ios/EasyFind/EasyFind.xcodeproj`，选择 `EasyFind` scheme。
2. 真机运行时，在 Signing & Capabilities 选择自己的 Team 和可用的 Bundle Identifier；仓库中的值来自当前原型配置，不包含签名证书或私钥。
3. 系统闹钟需要 iOS 26+。本机 Xcode 26.6 / Swift 6.3.3 可编译模拟器；仓库真机 SDK 使用 Swift 6.4，真机需 Xcode 27 或兼容当前编译器的 SDK，详见 [本机运行说明](本机运行说明.md)。模拟器可用 `-uiMock -selfieDemo -phoneFindAuthorized -featureTestControls` 演示页面，模拟结果不代表真实蓝牙或系统闹钟。
4. 固件目录为 `firmware/EasyFind-XIAO`，使用 PlatformIO 构建。详见 [固件说明](firmware/EasyFind-XIAO/README.md) 和 [BLE 协议](docs/selfie-stick-protocol-v0.1.md)。

仓库包含 App 源码、Xcode 工程、UI 资源、原工程的 FindMyTagKit 二进制依赖、固件源码与协议测试。不包含编译缓存、个人签名材料或开发板完整 Flash 备份。

---

## 原 FindMyTag SDK v1.4.3 说明

UWB 精准测距 SDK / UWB Precision Ranging SDK — iOS 二进制库 + 客户示例工程

## 目录结构

```
findmytag-sdk-ios-v1.4.3/
├── README.md                    本说明
├── docs/                        SDK 文档（集成指南、TransportHandle、协议、FAQ、CHANGELOG）
└── ios/
    ├── FindMyTagKit.xcframework  SDK 二进制库（真机 arm64 + 模拟器 arm64/x86_64）
    └── EasyFind/                 客户 App 工程（EasyFind 完整 UI 源码）
        ├── EasyFind.xcodeproj    可直接打开的工程（xcodegen 生成，可用 project.yml 重新生成）
        ├── project.yml           XcodeGen 配置（工程结构 / 库引用 / 签名设置）
        ├── Sources/              App 壳 + 全部 UI 源码（Swift）
        ├── Assets.xcassets       图标与资源
        └── Info.plist            应用配置
```

## 快速开始 / Quick Start

1. **打开工程**：直接打开 `ios/EasyFind/EasyFind.xcodeproj`（无需 pod / SPM）。
2. **依赖说明**：App 通过 XcodeGen 引用 `../FindMyTagKit.xcframework`（SDK 二进制库，自动嵌入）；UI 侧代码（扫描、测距、雷达界面等）以 **Swift 源码**形式随工程提供，可直接修改。
3. **签名**：在工程 Target → Signing & Capabilities 中设置你自己的 Team 与 Bundle ID。
4. **运行**：选择模拟器或真机（真机需 UWB 支持机型并配置 Nearby Interaction 权限）运行。

> 工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 生成：若需调整配置，改 `project.yml` 后执行 `xcodegen generate`。

## 修改 UI

所有界面源码在 `ios/EasyFind/Sources/`：

| 目录 | 内容 |
|------|------|
| `App/` | AppDelegate / SceneDelegate（应用入口） |
| `Home/` | 首页：扫描 Tag、底部 Tag 列表弹层 |
| `Ranging/` | 测距界面：雷达方向指示、距离、方向丢失、"就在附近"、声音/结束按钮 |
| `Services/` | 蓝牙传输、测距服务（调用 SDK 接口） |
| `Support/` | 权限申请等工具 |

## SDK 接口

模块名：`FindMyTagKit`（`import FindMyTagKit`）。核心类 `FindMyTagSDK`、`TransportHandle`（BLE 抽象）、`TagRangingService` 等用法见 [集成指南](docs/integration-guide.md) 与 [TransportHandle 指南](docs/transport-handle-guide.md)。

## 文档目录 / Documentation

| 文档 | 说明 |
|------|------|
| [集成指南](docs/integration-guide.md) | SDK 导入、权限、初始化、完整使用流程 |
| [TransportHandle 指南](docs/transport-handle-guide.md) | BLE 传输抽象实现指南 + 参考代码 |
| [Flutter 指南](docs/flutter-integration-guide.md) | Flutter Platform Channel 桥接 |
| [协议概述](docs/protocol-overview.md) | OOB 协议说明 |
| [FAQ](docs/faq.md) | 常见问题与故障排除 |
| [CHANGELOG](docs/CHANGELOG.md) | 版本历史 |

## 版本

v1.4.3 — 自 `brand/hycfind-dev` 分支构建，SDK 以二进制库交付，UI 以源码交付。

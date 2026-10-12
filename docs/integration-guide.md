# FindMyTag SDK 集成指南

## 1. 概述

FindMyTag SDK 为您的 iOS App 提供配合 芯邦UWB 的精准测距能力。
集成 SDK 后，您的 App 可实现厘米级近距离定位。

**功能：**
- UWB 精准测距
- UWB 会话自动恢复（peer disconnect → 重新 OOB）
- 配件指令：播放声音、停止声音、查询电量
- 多会话并发（受手机 UWB 芯片限制）

**不包含：**
- BLE 设备扫描与发现（您的 App 自行管理）
- BLE 连接管理（通过 `TransportHandle` 注入已建立的连接）
- 任何 UI 组件
- 后端 API 集成

## 2. 环境要求

| 项目 | 要求 |
|------|------|
| iOS 版本 | 16.0+ |
| Swift | 5.9+ |
| Xcode | 15.0+ |
| 设备 | iPhone 11+（U1 芯片）以上|

> **注意**：UWB 功能仅真机支持。模拟器可编译通过但无法测距。

## 3. 集成步骤

### 3.1 导入 SDK

1. 将 `FindMyTagKit.xcframework` 拖入 Xcode 项目
2. 在 Target → General → Frameworks, Libraries, and Embedded Content 中确保设置为 **Embed & Sign**

SDK 仅使用系统框架（NearbyInteraction、CoreBluetooth），无需额外依赖。

> **模块名说明**：framework / 模块名为 `FindMyTagKit`（`import FindMyTagKit`），
> 入口类仍为 `FindMyTagSDK`。二者名称不同是为了避免 Swift 模块与同名类的
> 命名冲突（apple/swift#56573），从而保证二进制框架可跨 Xcode 版本引入。

### 3.2 权限声明

在 `Info.plist` 中添加：

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>需要蓝牙权限以连接 UWB 配件</string>
<key>NSNearbyInteractionUsageDescription</key>
<string>需要近距离交互权限以进行 UWB 测距</string>
<key>NSCameraUsageDescription</key>
<string>需要相机权限以启用 AR 辅助定位</string>
```

> **注意**：`NSCameraUsageDescription` 仅在启用 AR 融合时需要。如不启用可省略。


### 3.3 初始化 SDK

```swift
import FindMyTagKit

// 默认配置（默认启用 AR 融合，需要相机权限）
let sdk = FindMyTagSDK()

// 不启用 AR 融合
let sdk = FindMyTagSDK(config: .init(enableARFusion: false))
```

### 3.4 实现 TransportHandle

SDK 不管理 OOB 连接。您需要实现 `TransportHandle` 协议，将已建立的 BLE GATT 连接注入 SDK。

> 详细指南：[TransportHandle 实现指南](transport-handle-guide.md)

### 3.5 创建会话并接收测距数据

```swift
// 1. 您的 App 扫描并连接 BLE 配件（方式不限）
let peripheral: CBPeripheral = /* 已连接的配件 */

// 2. 创建 TransportHandle（参考实现见 TransportHandle 指南）
let transport = CoreBluetoothTransport(peripheral: peripheral)

// 3. 创建测距会话
let session = sdk.createSession(transport: transport)

// 4. 设置回调
session.stateHandler = { state in
    switch state {
    case .idle:
        break
    case .connecting:
        print("连接中…")
    case .oobExchange(let phase):
        print("OOB 握手: \(phase)")
    case .ranging:
        print("测距中")
    case .recovering(let reason):
        // SDK 自动恢复中，无需客户干预
        print("UWB 恢复中: \(reason)")
    case .suspended:
        // iOS 挂起 NISession（如 App 进入后台），系统恢复后自动重新握手
        print("已挂起")
    case .transportLost:
        // BLE 断连 — 重建连接后替换 transport
        let newTransport = CoreBluetoothTransport(peripheral: reconnectedPeripheral)
        session.replaceTransport(newTransport)
    case .error(let reason):
        print("错误: \(reason)")
    }
}

session.rangingHandler = { m in
    print("距离: \(String(format: "%.2f", m.distance))m")
    if let az = m.azimuth {
        print("方位角: \(String(format: "%.1f", az))°")
    }
    if let el = m.elevation {
        print("俯仰角: \(String(format: "%.1f", el))°")
    }
    print("收敛: \(m.isConverged ? "是" : "否")")
}

// 5. 开始测距
session.startRanging()
```

### 3.6 启用 AR 融合

初始化 SDK 时默认启用摄像头辅助。

SDK 内部自动配置 `NINearbyAccessoryConfiguration.isCameraAssistanceEnabled = true`，
利用 iPhone 摄像头辅助 UWB 定位，提升精度和稳定性。

启用后：
- `RangingMeasurement.distance` 返回融合后距离
- `RangingMeasurement.rawUwbDistance` 返回原始 UWB 距离
- `RangingMeasurement.isConverged` 指示融合算法是否收敛

> **注意**：AR 融合需要相机权限。确保已在 Info.plist 中声明 `NSCameraUsageDescription`。

### 3.7 发送配件指令

```swift
// 播放声音
do {
    try session.playSound()
} catch {
    print("播放失败: \(error)")
}

// 停止声音
try session.stopSound()

// 查询电量（异步回调，有 5 秒超时）
session.requestBattery { result in
    switch result {
    case .success(let level):
        print("电量: \(level)%")
    case .failure(let error):
        print("查询失败: \(error)")
    }
}
```

### 3.8 释放资源

```swift
session.close()    // 关闭会话 + TransportHandle
sdk.release()      // 释放 SDK 资源
```

> **重要**：`session.close()` 会自动调用 `TransportHandle.close()`，释放 BLE 资源。

## 4. 完整示例

完整集成示例请参考 Demo App 源码：
- TransportHandle 实现：`ios/FindMyTagDemo/Sources/Transport/DemoTransportHandle.swift`
- 测距界面：`ios/FindMyTagDemo/Sources/Ranging/RangingViewController.swift`
- 扫描界面：`ios/FindMyTagDemo/Sources/Scan/ScanViewController.swift`

## 5. 权限清单速查

| 权限 | Info.plist Key | 何时需要 |
|------|---------------|---------|
| 蓝牙 | `NSBluetoothAlwaysUsageDescription` | 始终 |
| UWB | `NSNearbyInteractionUsageDescription` | 始终 |
| 相机 | `NSCameraUsageDescription` | 仅 `enableARFusion = true` |
| UWB Multipath | `com.apple.developer.nearby-interactions.multipath` (Entitlements) | 始终 |

## 6. 版本兼容性

| SDK 版本 | iOS 版本 | Swift 版本 | 说明 |
|---------|---------|-----------|------|
| 1.0.0 | 16.0+ | 5.9+ | 首个正式版本 |
| 1.1.0 | 16.0+ | 5.9+ | UWBSeek 品牌、Flutter 参考工程 |
| 1.4.2 | 16.0+ | 5.9+ | NISession 距离异常过滤、`suspended` 状态、移除外部 ARSession |

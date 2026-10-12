# Changelog

## [1.4.2] - 2026-06-26

### 新增 / Added (iOS)
- **NISession 异常距离过滤** — 在测距回调中增加两层异常值过滤器，丢弃 NISession 偶发的距离跳变：
  - 绝对上限：距离 > 80m 直接丢弃
  - 单帧跳变：远离方向跳变 > 20m 丢弃；靠近方向永远放行
  - `startRanging()` / OOB 重握手时自动重置过滤器基线
- `RangingMeasurement.estimateLevel` — 估计级别：`0` = 完整融合（range+bearing），`1` = 降级，`2` = 纯 UWB 距离
- `SessionState.suspended` — iOS 系统挂起 NISession（如 App 进入后台）时的新状态，系统恢复后自动重新握手

### 变更 / Changed
- **framework / 模块名 `FindMyTagSDK` → `FindMyTagKit`** — 消除模块与同名入口类的命名冲突（apple/swift#56573），便二进制 xcframework 可跨 Xcode 版本引入。`import FindMyTagKit`，入口类仍为 `FindMyTagSDK`（API 不变）；交付物为 `FindMyTagKit.xcframework`
- `WatchdogConfig` 默认超时收紧：`initTimeout` 5s → 3s，`noUpdateTimeout` 3s → 6s（给重新连接留更多时间）
- `SessionState.recovering` / `.error` 的关联值统一为 ``SessionStopReason``（含 `shouldRetry` 重连决策）
- `.suspended` 不计入活跃状态，后台时 watchdog 不再误触发 session 恢复
- XCFramework 重新打包（arm64 真机 + arm64/x86_64 模拟器）

### 移除 / Removed
- 外部 `ARSession` 注入方案完全移除（`FindMyTagSDK.Config.externalARSession`、外部 ARKit 姿态跟踪、航位推算模拟器）
- 移除运行时 `setCameraAssistanceEnabled(_:)` API — camera assistance 由 `Config.enableARFusion` 在初始化时决定

## [1.1.0] - 2026-06-06

### 变更 / Changed
- 品牌更新（UWBSeek）
- 新增 Flutter 参考工程（`flutter-app/`），演示 Platform Channel 桥接
- 文档与交付包结构整理

## [1.0.0] - 2026-05-14

### Added (iOS)
- UWB 精准测距（NI Accessory 协议）
- ARKit 传感器融合辅助定位（`enableARFusion`）
- OOB 四步握手协议
- UWB 会话自动恢复（peer disconnect → 重新 OOB）
- 配件指令：`playSound()`、`stopSound()`、`requestBattery()`
- 传输抽象层（`TransportHandle`）— 客户自行注入 BLE 连接
- 传输恢复（`replaceTransport()`）— BLE 断连后恢复
- 多会话支持（受设备 UWB 芯片限制）
- 闭包便利适配器（`ReceiveCallbackAdapter`）
- iOS 16+ `NINearbyAccessoryConfiguration` 支持（通过 `bluetoothPeerIdentifier`）
- XCFramework 交付包（符号剥离 + Release 编译优化）

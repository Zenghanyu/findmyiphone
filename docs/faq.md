# FAQ / 常见问题

## 集成

### Q: SDK 支持哪些 iOS 设备？

iPhone 11 及以上所有搭载 U1/U2 芯片的设备：

角度测量（`azimuth` / `elevation`）可能因设备不同而异，返回 `nil` 表示不支持。

### Q: SDK 需要哪些运行时权限？

见 [集成指南 — 权限清单](integration-guide.md#5-权限清单速查)。

### Q: 可以同时测距多个配件吗？

可以。每个配件创建独立的 `TransportHandle` 和 `RangingSession`：

```swift
let session1 = sdk.createSession(transport: transport1)
let session2 = sdk.createSession(transport: transport2)
session1.startRanging()
session2.startRanging()
```

并发数受手机 UWB 芯片限制。拒绝新会话时，`stateHandler` 会收到 `error` 事件。

### Q: enableARFusion 有什么效果？

SDK 内部配置 `NINearbyAccessoryConfiguration.isCameraAssistanceEnabled = true`，
利用后置摄像头辅助 UWB 定位，提升精度和稳定性。

启用后：
- 需要相机权限（`NSCameraUsageDescription`）
- `distance` 返回融合后距离
- 通过 `isConverged` 判断算法是否收敛

### Q: 不启用 AR 融合有什么区别？

不启用时，`distance` = `rawUwbDistance`（原始 UWB 测距值），`isConverged` 恒为 `true`。
测距精度依赖 UWB 芯片本身，无额外传感器辅助。

### Q: App 进入后台后测距会怎样？

iOS 会挂起 NISession，SDK 将状态设为 `suspended`。App 回到前台后，SDK 自动重新执行
OOB 握手并恢复测距（`suspended → oobExchange → ranging`），无需调用方干预。

### Q: 偶尔出现远超实际的距离跳变值怎么办？

SDK 内置 NISession 异常距离过滤器，自动丢弃明显异常的测距帧：

- 绝对上限：距离 > 80m 直接丢弃
- 单帧跳变：远离方向跳变 > 20m 丢弃（靠近方向始终放行）

过滤器基线在 `startRanging()` 与每次 OOB 重握手时自动重置。

## 故障排除

### Q: OOB 握手一直卡在 `oobExchange` 状态

**可能原因：**
1. `TransportHandle` 的 `registerReceiveCallback` 未正确将配件数据传递回 SDK
2. BLE 通知（Notify）未启用 — 确保对 TX Characteristic 调用了 `setNotifyValue(true, for:)`
3. 配件固件不兼容

**排查：**
1. 在 `ReceiveCallback.onReceiveData` 中打印日志，确认是否收到数据
2. 用 BLE 调试 App（如 LightBlue）验证手动写入 `0x0A` 后配件是否响应

### Q: 测距数据频繁跳变

**可能原因：**
1. UWB 信号受遮挡或多径反射
2. 未启用 AR 融合

**建议：**
1. 启用 `enableARFusion` 平滑测距数据
2. 检查 `isConverged` — 未收敛时数据不可靠
3. 确保配件与手机之间无金属遮挡

### Q: transportLost 后无法恢复

**排查步骤：**
1. 确认 App 已重新连接 BLE（`centralManager.connect(peripheral)`）
2. 创建**新的** `TransportHandle` 实例（不要复用旧的）
3. 调用 `session.replaceTransport(newTransport)`
4. 确认服务发现完成后再传入 SDK

### Q: NearbyInteraction 报 "session invalidated"

**可能原因：**
1. App 进入后台 — NearbyInteraction 在后台会被系统暂停
2. 权限未授予

**解决方案：**
1. 确保在前台使用 SDK
2. 检查 NearbyInteraction 权限和 Entitlements 是否正确配置
3. SDK 内置 UWB 恢复机制，短暂中断后会自动重新 OOB

### Q: requestBattery 超时

电量查询有 5 秒超时。超时可能因为：
1. 配件固件不支持电量查询指令（`0xB0`）
2. BLE 传输通道拥塞

确认配件固件支持 `0xB0` 指令，且 BLE 连接稳定。

### Q: iPhone 模拟器能使用 UWB 吗？

不能。UWB（NearbyInteraction）仅真机支持。模拟器可编译通过但无法实际测距。

### Q: 如何调试 OOB 协议通信？

1. 在 `ReceiveCallback.onReceiveData` 中打印收到的字节（hex dump）
2. 在 `sendData(_:)` 中打印发送的字节
3. 确认 Message ID 序列符合预期：`0x0A` → `0x01` → `0x0B` → `0x02`

> 注意：Release 构建中 SDK 已剥离所有调试日志，需在 Debug 模式下测试。

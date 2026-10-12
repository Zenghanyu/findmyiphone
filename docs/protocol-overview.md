# NI Accessory OOB 协议概述

## 1. 概述

FindMyTag SDK 使用 Apple NI Accessory Protocol 与 UWB 配件通信。OOB（Out-of-Band）握手
通过 `TransportHandle` 完成，之后 UWB 芯片直接测距。

SDK 内部自动处理 OOB 流程 — 您只需提供 `TransportHandle` 传输通道，无需关心协议细节。
本文档供希望了解底层机制的开发者参考。

## 2. 四步握手流程

```
手机 (Initiator)                 配件 (Accessory)
       │                               │
       │──── 0x0A (Init) ─────────────►│   步骤 1: 手机发起初始化
       │                               │
       │◄─── 0x01 (Config Data) ──────│   步骤 2: 配件返回 UWB 配置
       │                               │          (STS key, channel, etc.)
       │                               │
       │──── 0x0B (Configure &  ──────►│   步骤 3: 手机创建 NI session
       │      Start)                   │          并发送启动指令
       │                               │
       │◄─── 0x02 (Did Start) ────────│   步骤 4: 配件确认 UWB 已启动
       │                               │
       ╔═══════════════════════════════╗
       ║     UWB 测距 / Ranging       ║
       ╚═══════════════════════════════╝
       │                               │
       │──── 0x0C (Stop) ─────────────►│   停止: 手机发送停止指令
       │                               │
       │◄─── 0x03 (Did Stop) ─────────│   配件确认停止
       │                               │
```

## 3. 消息格式

每条 OOB 消息的第一个字节为 Message ID：

| Message ID | 方向 | 名称 | 说明 |
|-----------|------|------|------|
| `0x0A` | 手机→配件 | Init | 初始化请求 |
| `0x01` | 配件→手机 | AccessoryConfigurationData | 包含 UWB 配置参数 |
| `0x0B` | 手机→配件 | ConfigureAndStart | 发送手机端 UWB 配置 + 启动 |
| `0x02` | 配件→手机 | DidStart | 确认 UWB 测距已启动 |
| `0x0C` | 手机→配件 | Stop | 停止测距 |
| `0x03` | 配件→手机 | DidStop | 确认测距已停止 |

## 4. UWB 配置参数

OOB 握手中交换的关键 UWB 参数：

| 参数 | 说明 |
|------|------|
| UWB Channel | UWB 信道（如 9） |
| Preamble Index | 前导码索引 |
| SessionKeyInfo | 8 字节: `[VendorID:2][STS_IV:6]` |
| STS Config | 加扰时间戳序列配置 |

## 5. 配件指令

除 OOB 协议外，SDK 支持以下配件指令（通过 `RangingSession` 方法调用）：

| 指令 | 方法 | 字节 | 说明 |
|------|------|------|------|
| Play Sound | `playSound()` | `0xA0` | 播放配件蜂鸣器 |
| Stop Sound | `stopSound()` | `0xA1` | 停止蜂鸣器 |
| Request Battery | `requestBattery(completion:)` | `0xB0` | 查询电量，配件回复 `[0xB0, level]` |

## 6. 会话恢复

SDK 内置 UWB 层自动恢复机制：

1. **UWB Peer Disconnect**: UWB 芯片报告 peer 断开，SDK 等待短暂宽限期
2. **宽限期内恢复**: peer 重新出现，继续测距
3. **宽限期超时**: SDK 通过 `TransportHandle` 重新执行 OOB 握手
4. **多次重建失败**: 达到最大重试次数后，`stateHandler` 收到 `error`

状态变化序列：

```
ranging → recovering(.noRangesTimeout) → [恢复成功] → ranging
ranging → recovering(.noRangesTimeout) → ... → error(reason)   // reason.shouldRetry == false
```

> `recovering` / `error` 的关联值为 ``SessionStopReason``，可通过 `reason.shouldRetry`
> 判断 SDK 是否会自动重试。

**App 进入后台**：iOS 会挂起 NISession。SDK 将状态设为 `suspended`，系统恢复（回到前台）
后自动重新执行 OOB 握手，无需 App 干预。

```
ranging → suspended → [App 回到前台] → oobExchange → ranging
```

**BLE 断连恢复**：BLE 层断连由您的 App 负责。SDK 将状态设为 `transportLost`，
您的 App 重建 BLE 连接后调用 `session.replaceTransport(newTransport)` 恢复。

```
ranging → transportLost → [App 重连 BLE] → replaceTransport(newTransport) → ranging
```

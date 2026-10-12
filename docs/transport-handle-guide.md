# TransportHandle 实现指南

## 1. 接口说明

`TransportHandle` 是 SDK 与 BLE 传输之间的抽象层。SDK 不直接操作蓝牙 — 您通过实现
`TransportHandle` 协议注入已建立的 BLE GATT 连接。

### 协议定义

```swift
public protocol TransportHandle: AnyObject {
    func sendData(_ data: Data)
    func registerReceiveCallback(queue: DispatchQueue, callback: ReceiveCallback)
    func close()
    var bluetoothPeerIdentifier: UUID? { get }  // 可选，提供以提升精度
}

public protocol ReceiveCallback: AnyObject {
    func onReceiveData(_ data: Data)
    func onSendFailed(reason: Error?)
    func onClose()
}
```

### 方法语义

| 方法 | 说明 |
|------|------|
| `sendData(_:)` | 向配件发送字节数据。可从任意线程调用。SDK 在 OOB 握手和测距期间多次调用。 |
| `registerReceiveCallback(queue:callback:)` | SDK 创建会话时调用一次。配件返回数据时，通过 `callback` 传递给 SDK。 |
| `close()` | 关闭传输通道。SDK 在 `RangingSession.close()` 时调用。应触发 `ReceiveCallback.onClose()`。 |
| `bluetoothPeerIdentifier` | 可选。提供 `CBPeripheral.identifier` 可启用 iOS 16+ `NINearbyAccessoryConfiguration` 新 API，提升会话匹配精度。不提供则自动回退到 `init(data:)`。 |

### 线程约定

- `sendData(_:)` 可从任意线程调用，实现需保证线程安全
- `ReceiveCallback` 通过您指定的 `DispatchQueue` 回调
- SDK 不会并发调用 `sendData(_:)`，但可能在回调执行期间调用

## 2. 生命周期

```
您的 App 创建 BLE 连接
    │
    ▼
创建 TransportHandle ──────────┐
    │                            │
    ▼                            │
sdk.createSession(transport:)    │ 1:1 绑定
    │                            │
    ▼                            │
session.startRanging()           │
    │                            │
    ▼                            │
[... 测距进行中 ...]             │
    │                            │
    │  (BLE 断连)                │
    ▼                            │
stateHandler(.transportLost)     │
    │                            │
    ▼                            │
重建 BLE 连接                     │
    │                            │
    ▼                            │
session.replaceTransport(new)    │  新的 TransportHandle
    │                            │
    ▼                            │
session.close()                  │
    │                            │
    ▼                            │
TransportHandle.close() ◄────────┘
```

**重要规则：**
- 一个 `TransportHandle` 对应一个 `RangingSession`，不可复用
- BLE 断连时，SDK 将状态设为 `transportLost`。重建 BLE 连接后，创建**新的** `TransportHandle` 实例，调用 `session.replaceTransport(newTransport)`
- **不要复用旧的 TransportHandle** — 旧的 BLE 连接已失效

## 3. BLE GATT 参考实现

以下代码展示如何基于标准 BLE GATT 实现 `TransportHandle`。您可直接复制
并根据自己的 BLE 栈调整。

### BLE 服务 UUID

| 名称 | UUID | 说明 |
|------|------|------|
| NI Service | `00002761-08C2-11E1-9073-0E8AC72E1001` | NI Accessory 主服务 |
| RX Characteristic | `00002761-08C2-11E1-9073-0E8AC72E0001` | 手机→配件（Write） |
| TX Characteristic | `00002761-08C2-11E1-9073-0E8AC72E0002` | 配件→手机（Notify） |

### 基础参考实现

```swift
import CoreBluetooth
import FindMyTagKit

final class CoreBluetoothTransport: NSObject, TransportHandle, CBPeripheralDelegate {

    private let peripheral: CBPeripheral
    private var rxCharacteristic: CBCharacteristic?
    private var receiveCallback: (any ReceiveCallback)?
    private var callbackQueue: DispatchQueue?
    private var closed = false

    /// 可选：为 iOS 16+ 提供 bluetoothPeerIdentifier 以提升会话匹配精度
    var bluetoothPeerIdentifier: UUID? { peripheral.identifier }

    // BLE 服务 UUID
    private static let niServiceUUID = CBUUID(string: "00002761-08C2-11E1-9073-0E8AC72E1001")
    private static let rxCharUUID    = CBUUID(string: "00002761-08C2-11E1-9073-0E8AC72E0001")
    private static let txCharUUID    = CBUUID(string: "00002761-08C2-11E1-9073-0E8AC72E0002")

    /// 初始化后自动发现服务
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    func sendData(_ data: Data) {
        guard !closed, let rx = rxCharacteristic else { return }
        peripheral.writeValue(data, for: rx, type: .withResponse)
    }

    func registerReceiveCallback(queue: DispatchQueue, callback: any ReceiveCallback) {
        self.callbackQueue = queue
        self.receiveCallback = callback
        peripheral.discoverServices([Self.niServiceUUID])
    }

    func close() {
        guard !closed else { return }
        closed = true
        peripheral.delegate = nil
        rxCharacteristic = nil
        receiveCallback = nil
        callbackQueue = nil
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            dispatch { [weak self] in self?.receiveCallback?.onSendFailed(reason: error) }
            return
        }
        guard let service = peripheral.services?.first(where: {
            $0.uuid == Self.niServiceUUID
        }) else { return }
        peripheral.discoverCharacteristics(
            [Self.rxCharUUID, Self.txCharUUID], for: service
        )
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        if let error {
            dispatch { [weak self] in self?.receiveCallback?.onSendFailed(reason: error) }
            return
        }
        for char in service.characteristics ?? [] {
            if char.uuid == Self.rxCharUUID {
                rxCharacteristic = char
            } else if char.uuid == Self.txCharUUID {
                peripheral.setNotifyValue(true, for: char)
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            dispatch { [weak self] in self?.receiveCallback?.onSendFailed(reason: error) }
            return
        }
        guard characteristic.uuid == Self.txCharUUID,
              let data = characteristic.value else { return }
        dispatch { [weak self] in self?.receiveCallback?.onReceiveData(data) }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if let error {
            dispatch { [weak self] in self?.receiveCallback?.onSendFailed(reason: error) }
        }
    }

    // MARK: - Private

    private func dispatch(_ block: @escaping () -> Void) {
        (callbackQueue ?? .main).async(execute: block)
    }
}
```

### 使用方式

```swift
// 1. 您的 App 扫描并连接 CBPeripheral（方式不限）
let peripheral: CBPeripheral = /* 已连接 */

// 2. 创建 TransportHandle
let transport = CoreBluetoothTransport(peripheral: peripheral)
// CoreBluetoothTransport 将自己设为 peripheral.delegate

// 3. 传入 SDK
let session = sdk.createSession(transport: transport)
session.startRanging()
```

### 带发送队列的增强版

如果需要在 GATT 就绪前缓存待发送数据（推荐用于生产环境）：

```swift
final class BufferedTransport: NSObject, TransportHandle, CBPeripheralDelegate {
    // ... 与 CoreBluetoothTransport 相同的基础代码 ...

    private var pendingWrites: [Data] = []
    private var gattReady = false

    func sendData(_ data: Data) {
        if gattReady, let rx = rxCharacteristic {
            peripheral.writeValue(data, for: rx, type: .withResponse)
        } else {
            pendingWrites.append(data)  // 缓存，等服务发现完成后刷新
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard error == nil,
              characteristic.uuid == Self.txCharUUID,
              characteristic.isNotifying,
              rxCharacteristic != nil else { return }
        gattReady = true
        // 刷新缓存
        let queued = pendingWrites
        pendingWrites.removeAll()
        for data in queued {
            peripheral.writeValue(data, for: rxCharacteristic!, type: .withResponse)
        }
    }
}
```

> 完整带队列实现参考 Demo App：`ios/FindMyTagDemo/Sources/Transport/DemoTransportHandle.swift`

## 4. 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| OOB 握手卡在 `oobExchange` | TX 特征 Notify 未启用 | 确保 `setNotifyValue(true, for: txChar)` 已调用 |
| 数据接收不到 | `ReceiveCallback` 未正确注册 | 确认 `registerReceiveCallback` 被 SDK 调用 |
| Write 无响应 | 特征未发现或类型错误 | 使用 `withResponse` 写入类型，确保特征 UUID 正确 |
| `transportLost` 频繁触发 | BLE 信号弱或配件距离过远 | 缩短距离，或添加客户端自动重连逻辑 |
| 连接后立即断连 | BLE 服务未就绪 | 等待 `didDiscoverServices` + `didUpdateNotificationStateFor` 后再使用 |

import CoreBluetooth
import FindMyTagKit

/// BLE GATT 传输通道：实现 `TransportHandle`，供 SDK 会话使用。
/// 从 UWBSeek Runner 移植，将 RSSI 上报改为闭包回调（原实现耦合 TagMonitorService）。
final class CoreBluetoothTransport: NSObject, TransportHandle, CBPeripheralDelegate {

    private let peripheral: CBPeripheral
    private var writeChar: CBCharacteristic?
    private var callbackQueue: DispatchQueue?
    private var receiveCallback: (any ReceiveCallback)?

    /// GATT 就绪（服务+特征已发现、notify 已订阅）后触发；已就绪时设置立即触发。
    var onGattReady: (() -> Void)? {
        didSet {
            if gattReady {
                onGattReady?()
            }
        }
    }

    /// 读取到 RSSI 时回调（原 Runner 实现写入 TagMonitorService，此处解耦）。
    var onRssiRead: ((Int) -> Void)?

    private var pendingWrites: [Data] = []
    private var gattReady = false
    /// 已发起过 GATT discovery，防止重复 discoverServices。
    private var discoveryStarted = false

    /// A2 解绑同步（协议 §7）：收到 0xA2 开头帧时回调（主队列），不进 SDK 会话。
    var onA2Frame: ((Data) -> Void)?
    /// A2 写请求（Write Request）的完成回调。
    private var a2WriteCompletion: ((Bool) -> Void)?
    /// 连接建立后待发的 A2 00 查询（GATT ready 后发一次）。
    private var a2QueryPending = false
    private let a2QueryData = Data([0xA2, 0x00])

    var bluetoothPeerIdentifier: UUID? { peripheral.identifier }

    /// GATT 是否已就绪。
    var isGattReady: Bool { gattReady }

    /// 当前 MTU 下单次可靠写入的最大字节数。
    /// 优先 `.withoutResponse` 上限（Write Command 不触发 Long Write 分片）。
    var maxWritePayloadLength: Int {
        let w = peripheral.maximumWriteValueLength(for: .withoutResponse)
        return w > 0 ? w : peripheral.maximumWriteValueLength(for: .withResponse)
    }

    /// 所有写状态在主队列串行访问（CBCentralManager delegate queue = main）。
    private func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }

    private static let niServiceUUID = CBUUID(string: "00002761-08C2-11E1-9073-0E8AC72E1001")
    private static let writeCharUUID  = CBUUID(string: "00002761-08C2-11E1-9073-0E8AC72E0001")
    private static let notifyCharUUID = CBUUID(string: "00002761-08C2-11E1-9073-0E8AC72E0002")

    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        peripheral.delegate = self
    }

    // MARK: - TransportHandle

    /// 固定用 Write Command（`.withoutResponse`）。
    /// 外设 GATT 不支持 Long Write 重组，`.withoutResponse` 不分片。
    private func writeData(_ data: Data) {
        guard let char = writeChar else { return }
        peripheral.writeValue(data, for: char, type: .withoutResponse)
    }

    func sendData(_ data: Data) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if self.gattReady, let _ = self.writeChar {
                self.writeData(data)
            } else {
                self.pendingWrites.append(data)
            }
        }
    }

    /// 使能 A2 解绑同步：拦截 0xA2 帧，并在 GATT ready 后自动发一次 A2 00 查询。
    func startA2UnbindSync(onFrame: @escaping (Data) -> Void) {
        runOnMain { [weak self] in
            guard let self else { return }
            self.onA2Frame = onFrame
            self.a2QueryPending = true
            self.ensureGattDiscovery()
        }
    }

    /// A2 指令写请求（协议 §6.1/§7：Control Point 用 Write Request）。
    func writeA2Command(_ data: Data, completion: @escaping (Bool) -> Void) {
        runOnMain { [weak self] in
            guard let self, let char = self.writeChar else {
                completion(false)
                return
            }
            self.a2WriteCompletion = completion
            self.peripheral.writeValue(data, for: char, type: .withResponse)
        }
    }

    private func ensureGattDiscovery() {
        guard writeChar == nil, !discoveryStarted else { return }
        discoveryStarted = true
        peripheral.discoverServices([Self.niServiceUUID])
    }

    func registerReceiveCallback(queue: DispatchQueue, callback: any ReceiveCallback) {
        runOnMain { [weak self] in
            guard let self = self else { return }
            self.callbackQueue = queue
            self.receiveCallback = callback
            if self.writeChar == nil {
                self.gattReady = false
                self.pendingWrites.removeAll()
                self.ensureGattDiscovery()
            } else {
                self.gattReady = true
                self.flushPending()
            }
        }
    }

    func close() {
        runOnMain { [weak self] in
            guard let self = self else { return }
            if self.peripheral.delegate === self {
                self.peripheral.delegate = nil
            }
            self.writeChar = nil
            self.pendingWrites.removeAll()
            self.receiveCallback = nil
            self.callbackQueue = nil
            self.gattReady = false
            self.onA2Frame = nil
            self.a2WriteCompletion = nil
            self.a2QueryPending = false
            self.discoveryStarted = false
        }
    }

    func signalClosed() {
        dispatch { [weak self] in self?.receiveCallback?.onClose() }
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            dispatch { [weak self] in self?.receiveCallback?.onSendFailed(reason: error) }
            return
        }
        guard let service = peripheral.services?.first(where: { $0.uuid == Self.niServiceUUID }) else { return }
        peripheral.discoverCharacteristics([Self.writeCharUUID, Self.notifyCharUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            dispatch { [weak self] in self?.receiveCallback?.onSendFailed(reason: error) }
            return
        }
        for c in service.characteristics ?? [] {
            if c.uuid == Self.writeCharUUID {
                writeChar = c
            }
            if c.uuid == Self.notifyCharUUID {
                peripheral.setNotifyValue(true, for: c)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil,
              characteristic.uuid == Self.notifyCharUUID,
              characteristic.isNotifying,
              writeChar != nil else { return }
        gattReady = true
        flushPending()
        onGattReady?()
        if a2QueryPending {
            a2QueryPending = false
            writeA2Command(a2QueryData) { _ in }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            dispatch { [weak self] in self?.receiveCallback?.onSendFailed(reason: error) }
            return
        }
        guard let data = characteristic.value else { return }
        // A2 解绑同步帧由 transport 拦截，不进 SDK 会话。
        if data.first == 0xA2 {
            onA2Frame?(data)
            return
        }
        dispatch { [weak self] in self?.receiveCallback?.onReceiveData(data) }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            NSLog("[CoreBluetoothTransport] write failed: \(error.localizedDescription)")
        }
        if let completion = a2WriteCompletion {
            a2WriteCompletion = nil
            completion(error == nil)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else { return }
        onRssiRead?(RSSI.intValue)
    }

    // MARK: - Private

    private func flushPending() {
        guard writeChar != nil else { return }
        let queued = pendingWrites
        pendingWrites.removeAll()
        for data in queued {
            writeData(data)
        }
    }

    private func dispatch(_ block: @escaping () -> Void) {
        (callbackQueue ?? .main).async(execute: block)
    }
}

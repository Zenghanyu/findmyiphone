import CoreBluetooth

/// 接入系统已配对的自拍杆，并让 Core Bluetooth 保留连接及通知订阅。
/// 首次接入仍由系统“设置 > 蓝牙”完成；这里不扫描或展示配对清单。
final class SelfieStickBluetoothTransport: NSObject, SelfieStickTransport, CBCentralManagerDelegate, CBPeripheralDelegate {
    var onReady: ((SelfieStickDevice) -> Void)?
    var onFrame: ((Data) -> Void)?
    var onDisconnected: (() -> Void)?
    var onError: ((String) -> Void)?
    var onWaiting: ((String) -> Void)?

    private let serviceUUID = CBUUID(string: SelfieStickProtocol.serviceUUID)
    private let commandUUID = CBUUID(string: SelfieStickProtocol.commandUUID)
    private let responseUUID = CBUUID(string: SelfieStickProtocol.responseUUID)
    private let knownPeripheralKey = "SelfieStickBluetooth.knownPeripheralUUID"
    private let maximumQueuedFrames = 64
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var selectedDevice: SelfieStickDevice?
    private var command: CBCharacteristic?
    private var response: CBCharacteristic?
    private var wantsStart = false
    private var ready = false
    private var reportedWaiting = false
    private var appConnectionEstablished = false
    private var connectionRequested = false
    private var awaitingDisconnect = false
    private var discovering = false
    private var recoveryFailures = 0
    private var reconnectDelay: TimeInterval = 0
    private var readySince: Date?
    private var channelTimeout: Timer?
    private var writeTimeout: Timer?
    private var queuedWrites: [Data] = []
    private var writeInFlight: Data?
    private var earlyFrames: [(data: Data, receivedAt: TimeInterval)] = []

    deinit {
        channelTimeout?.invalidate()
        writeTimeout?.invalidate()
    }

    func start() {
        wantsStart = true
        reportedWaiting = false
        ensureCentral()
    }

    func retry() {
        wantsStart = true
        reportedWaiting = false
        recoveryFailures = 0
        reconnectDelay = 0
        // Do not cancel an out-of-range pending connection just because a page
        // asks to refresh. That system-owned request survives app suspension.
        if ready, let selectedDevice {
            // A configuration timeout need not tear down a healthy subscribed
            // channel or disturb an ATT write that is still completing.
            onReady?(selectedDevice)
            return
        }
        ensureCentral()
    }

    func send(_ data: Data) {
        guard wantsStart else {
            onError?("系统蓝牙配置通道未启动，请重新检测")
            return
        }
        guard !data.isEmpty, data.count <= 20 else {
            onError?("自拍杆报文长度不正确")
            return
        }
        guard queuedWrites.count < maximumQueuedFrames else {
            PhoneFindDiagnostics.record("ble.writeQueueFull")
            onError?("自拍杆配置通道繁忙，请稍后重试")
            return
        }
        // Restored notifications may arrive before characteristic discovery.
        // Keep their ACKs until the write channel is ready. Only one ATT write
        // with response may be in flight; enable/read/ACK retain FIFO order.
        queuedWrites.append(data)
        drainWrites()
    }

    func disconnect() {
        wantsStart = false
        let old = peripheral
        old?.delegate = nil
        clearPeripheral()
        if let old, central?.state == .poweredOn {
            central?.cancelPeripheralConnection(old)
        }
    }

    private func ensureCentral() {
        if let central {
            handleState(central.state)
        } else {
            central = CBCentralManager(
                delegate: self,
                queue: .main,
                options: [CBCentralManagerOptionRestoreIdentifierKey: "com.luyuan.easyfind.selfiestick.central"]
            )
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        PhoneFindDiagnostics.record("ble.state=\(central.state.rawValue)")
        handleState(central.state)
    }

    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String: Any]) {
        guard wantsStart,
              let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] else { return }
        let remembered = UserDefaults.standard.string(forKey: knownPeripheralKey)
        guard let candidate = restored.first(where: { $0.identifier.uuidString == remembered }) ?? restored.first else { return }
        PhoneFindDiagnostics.record("ble.restored state=\(candidate.state.rawValue)")
        // This callback precedes didUpdateState. Install the delegate now to
        // receive queued notifications, but wait for poweredOn before BLE work.
        adopt(candidate, restored: true)
    }

    private func handleState(_ state: CBManagerState) {
        guard wantsStart else { return }
        switch state {
        case .poweredOn:
            if peripheral != nil { resumePeripheral() }
            else { restoreConnectedPeripheral() }
        case .poweredOff, .resetting:
            peripheral?.delegate = nil
            clearPeripheral()
            onWaiting?(state == .poweredOff
                ? "蓝牙已关闭，开启后会自动恢复连接"
                : "蓝牙正在恢复，稍后会自动检测自拍杆")
        case .unauthorized:
            peripheral?.delegate = nil
            clearPeripheral()
            onError?("请在系统设置中允许 EasyFind 使用蓝牙")
        case .unsupported:
            onError?("当前设备不支持蓝牙")
        case .unknown:
            break
        @unknown default:
            onError?("蓝牙暂不可用")
        }
    }

    private func restoreConnectedPeripheral() {
        guard wantsStart, peripheral == nil, let central, central.state == .poweredOn else { return }
        // Prefer the already configured accessory when several system devices
        // expose this service. An absent accessory leaves a pending connection.
        if let raw = UserDefaults.standard.string(forKey: knownPeripheralKey),
           let uuid = UUID(uuidString: raw),
           let remembered = central.retrievePeripherals(withIdentifiers: [uuid]).first {
            adopt(remembered)
            resumePeripheral()
            return
        }
        if let connected = central.retrieveConnectedPeripherals(withServices: [serviceUUID]).first {
            adopt(connected)
            resumePeripheral()
            return
        }
        guard !reportedWaiting else { return }
        reportedWaiting = true
        onWaiting?("未检测到系统已连接的自拍杆\n请先在 iPhone“设置 > 蓝牙”中连接设备，返回此页会自动读取")
    }

    private func adopt(_ candidate: CBPeripheral, restored: Bool = false) {
        clearPeripheral()
        reportedWaiting = false
        let name = candidate.name?.isEmpty == false ? candidate.name! : "自拍杆"
        selectedDevice = SelfieStickDevice(identifier: candidate.identifier, name: name)
        peripheral = candidate
        candidate.delegate = self
        appConnectionEstablished = restored && candidate.state == .connected
        connectionRequested = restored && candidate.state == .connecting
        PhoneFindDiagnostics.record("ble.adopt state=\(candidate.state.rawValue) restored=\(restored)")
    }

    private func resumePeripheral() {
        guard wantsStart, let central, central.state == .poweredOn, let peripheral,
              !awaitingDisconnect, !ready, !discovering else { return }
        switch peripheral.state {
        case .connected:
            if appConnectionEstablished { discoverChannel(on: peripheral) }
            else if !connectionRequested { requestConnection(to: peripheral) }
        case .connecting:
            // Only a restored/previously submitted request belongs to this
            // manager. The system HID link may itself merely be connecting.
            if !connectionRequested { requestConnection(to: peripheral) }
        case .disconnected:
            if !connectionRequested { requestConnection(to: peripheral) }
        case .disconnecting:
            // A system-connected HID link can be disconnecting before this
            // app has connected it. Register our request rather than waiting
            // for a disconnect callback that may belong to another client.
            if !connectionRequested { requestConnection(to: peripheral) }
        @unknown default:
            break
        }
    }

    private func requestConnection(to peripheral: CBPeripheral) {
        guard wantsStart, peripheral === self.peripheral, let central, central.state == .poweredOn else { return }
        appConnectionEstablished = false
        connectionRequested = true
        // Core Bluetooth owns both the backoff and the unbounded connection
        // wait. No app timer or execution time is needed for a returning device.
        let options: [String: Any]? = reconnectDelay > 0
            ? [CBConnectPeripheralOptionStartDelayKey: NSNumber(value: reconnectDelay)] : nil
        PhoneFindDiagnostics.record("ble.connectPending delay=\(reconnectDelay)")
        central.connect(peripheral, options: options)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard wantsStart, peripheral === self.peripheral else { return }
        connectionRequested = false
        appConnectionEstablished = true
        awaitingDisconnect = false
        PhoneFindDiagnostics.record("ble.connected")
        discoverChannel(on: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard wantsStart, peripheral === self.peripheral else { return }
        PhoneFindDiagnostics.record("ble.connectFailed error=\(error?.localizedDescription ?? "none")")
        clearChannel()
        connectionRequested = false
        appConnectionEstablished = false
        awaitingDisconnect = false
        increaseBackoff()
        onError?("自拍杆配置通道连接失败，正在自动重连")
        requestConnection(to: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        PhoneFindDiagnostics.record("ble.disconnected error=\(error?.localizedDescription ?? "none")")
        let wasRecovering = awaitingDisconnect
        clearChannel()
        if !wasRecovering { increaseBackoff() }
        appConnectionEstablished = false
        connectionRequested = false
        awaitingDisconnect = false
        onDisconnected?()
        if wantsStart, central.state == .poweredOn { requestConnection(to: peripheral) }
    }

    private func discoverChannel(on peripheral: CBPeripheral) {
        guard wantsStart, peripheral === self.peripheral, central?.state == .poweredOn,
              peripheral.state == .connected, !discovering, !ready else { return }
        discovering = true
        channelTimeout?.invalidate()
        channelTimeout = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            PhoneFindDiagnostics.record("ble.discoveryTimeout")
            self?.recoverChannel("自拍杆配置通道响应超时，正在自动恢复")
        }
        // A restored peripheral can retain the entire GATT database and an
        // active subscription. Do not rely on a redundant notify callback.
        if let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) {
            discoverCharacteristics(on: peripheral, service: service)
        } else {
            peripheral.discoverServices([serviceUUID])
        }
    }

    private func discoverCharacteristics(on peripheral: CBPeripheral, service: CBService) {
        if let command = service.characteristics?.first(where: { $0.uuid == commandUUID }),
           let response = service.characteristics?.first(where: { $0.uuid == responseUUID }) {
            configureChannel(command: command, response: response, on: peripheral)
        } else {
            peripheral.discoverCharacteristics([commandUUID, responseUUID], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard wantsStart, peripheral === self.peripheral, discovering, !awaitingDisconnect else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            recoverChannel("设备配置服务暂不可用，正在自动恢复")
            return
        }
        discoverCharacteristics(on: peripheral, service: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard wantsStart, peripheral === self.peripheral, service.uuid == serviceUUID,
              discovering, !awaitingDisconnect else { return }
        guard error == nil,
              let command = service.characteristics?.first(where: { $0.uuid == commandUUID }),
              let response = service.characteristics?.first(where: { $0.uuid == responseUUID }) else {
            recoverChannel("设备配置或通知通道暂不可用，正在自动恢复")
            return
        }
        configureChannel(command: command, response: response, on: peripheral)
    }

    private func configureChannel(command: CBCharacteristic, response: CBCharacteristic, on peripheral: CBPeripheral) {
        guard command.properties.contains(.write), response.properties.contains(.notify) else {
            recoverChannel("设备不支持当前自拍杆配置协议，将自动重新检测")
            return
        }
        self.command = command
        self.response = response
        if response.isNotifying { markReady() }
        else { peripheral.setNotifyValue(true, for: response) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard wantsStart, peripheral === self.peripheral, characteristic.uuid == responseUUID, !awaitingDisconnect else { return }
        guard error == nil, characteristic.isNotifying else {
            recoverChannel("无法接收自拍杆通知，正在自动恢复")
            return
        }
        // This can precede rediscovery during restoration; configureChannel
        // will finish readiness once both characteristic references exist.
        if command != nil { markReady() }
    }

    private func markReady() {
        guard wantsStart, !ready, !awaitingDisconnect, command != nil, response?.isNotifying == true,
              let selectedDevice else { return }
        channelTimeout?.invalidate()
        channelTimeout = nil
        discovering = false
        readySince = Date()
        ready = true
        UserDefaults.standard.set(selectedDevice.identifier.uuidString, forKey: knownPeripheralKey)
        PhoneFindDiagnostics.record("ble.subscribed")
        // Establish the service's device context before replaying notifications
        // that woke this process. onReady's writes are serialized with ACKs.
        let buffered = earlyFrames
        earlyFrames.removeAll()
        onReady?(selectedDevice)
        guard ready else { return }
        for frame in buffered {
            // Rediscovery can take seconds. Do not renew a cached request's TTL
            // while it waits in this process for the command characteristic.
            if let decoded = try? SelfieStickProtocol.Frame.decode(frame.data),
               let request = SelfieStickProtocol.PhoneFindRequest.decode(decoded) {
                let elapsed = max(0, ProcessInfo.processInfo.systemUptime - frame.receivedAt)
                let remaining = Double(request.remainingSeconds) - elapsed
                guard remaining > 0 else { continue }
                let adjusted = SelfieStickProtocol.PhoneFindRequest(id: request.id, remainingSeconds: UInt8(ceil(remaining)))
                if let data = try? adjusted.eventFrame().encoded() { onFrame?(data) }
            } else {
                onFrame?(frame.data)
            }
        }
        drainWrites()
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard wantsStart, peripheral === self.peripheral, characteristic.uuid == responseUUID, !awaitingDisconnect else { return }
        guard error == nil, let data = characteristic.value else {
            recoverChannel("自拍杆回复读取失败，正在自动恢复")
            return
        }
        PhoneFindDiagnostics.record("ble.frame bytes=\(data.count)")
        if ready { onFrame?(data) }
        else {
            if earlyFrames.count >= maximumQueuedFrames { earlyFrames.removeFirst() }
            earlyFrames.append((data, ProcessInfo.processInfo.systemUptime))
            PhoneFindDiagnostics.record("ble.frameBuffered")
        }
    }

    private func drainWrites() {
        guard ready, writeInFlight == nil, !queuedWrites.isEmpty, let peripheral,
              peripheral.state == .connected, let command else { return }
        let data = queuedWrites.removeFirst()
        guard data.count <= peripheral.maximumWriteValueLength(for: .withResponse) else {
            recoverChannel("自拍杆不支持当前报文长度，正在自动恢复")
            return
        }
        writeInFlight = data
        writeTimeout?.invalidate()
        writeTimeout = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            PhoneFindDiagnostics.record("ble.writeTimeout")
            self?.recoverChannel("自拍杆发送确认超时，正在自动恢复")
        }
        peripheral.writeValue(data, for: command, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard wantsStart, peripheral === self.peripheral, characteristic.uuid == commandUUID,
              writeInFlight != nil, !awaitingDisconnect else { return }
        writeTimeout?.invalidate()
        writeTimeout = nil
        writeInFlight = nil
        guard error == nil else {
            recoverChannel("自拍杆报文发送失败，正在自动恢复")
            return
        }
        // ATT completion allows the next write, but never confirms a flash
        // save or an accepted phone alarm; those use application-level replies.
        drainWrites()
    }

    func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        guard wantsStart, peripheral === self.peripheral,
              invalidatedServices.contains(where: { $0.uuid == serviceUUID }) else { return }
        PhoneFindDiagnostics.record("ble.servicesInvalidated")
        recoverChannel("自拍杆配置服务已更新，正在自动恢复")
    }

    private func increaseBackoff() {
        recoveryFailures = min(recoveryFailures + 1, 7)
        reconnectDelay = min(60, pow(2, Double(recoveryFailures - 1)))
    }

    private func recoverChannel(_ message: String) {
        guard wantsStart, let peripheral, !awaitingDisconnect else { return }
        clearChannel()
        increaseBackoff()
        onError?(message)
        guard let central, central.state == .poweredOn else { return }
        if peripheral.state == .connected || peripheral.state == .disconnecting {
            awaitingDisconnect = true
            central.cancelPeripheralConnection(peripheral)
        } else if peripheral.state == .disconnected {
            connectionRequested = false
            requestConnection(to: peripheral)
        }
        // Never cancel a pending connection because a local timer expired.
    }

    private func clearChannel() {
        // A channel that merely reaches subscribed and fails its first write
        // must retain backoff; otherwise a bad device can reconnect in a loop.
        if let readySince, Date().timeIntervalSince(readySince) >= 30 {
            recoveryFailures = 0
            reconnectDelay = 0
        }
        readySince = nil
        channelTimeout?.invalidate()
        channelTimeout = nil
        writeTimeout?.invalidate()
        writeTimeout = nil
        ready = false
        discovering = false
        command = nil
        response = nil
        queuedWrites.removeAll()
        writeInFlight = nil
        earlyFrames.removeAll()
    }

    private func clearPeripheral() {
        clearChannel()
        peripheral = nil
        selectedDevice = nil
        appConnectionEstablished = false
        connectionRequested = false
        awaitingDisconnect = false
    }
}

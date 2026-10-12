import CoreBluetooth

/// BLE 配置客户端。
///
/// 自拍杆先在 iOS“设置 > 蓝牙”中完成系统配对。App 只通过 retrieveConnectedPeripherals
/// 接入当前已经连接的自定义配置服务，不扫描附近设备，也不在页面里提供配对/选择流程。
/// 系统 HID 链路和这里的配置链路由同一个自拍杆分别维护。
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
    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var selectedDevice: SelfieStickDevice?
    private var command: CBCharacteristic?
    private var response: CBCharacteristic?
    private var wantsStart = false
    private var ready = false
    private var reportedWaiting = false
    private var connectionTimeout: Timer?

    deinit { connectionTimeout?.invalidate() }

    func start() {
        wantsStart = true
        reportedWaiting = false
        ensureCentral()
    }

    func retry() {
        wantsStart = true
        reportedWaiting = false
        ready = false
        command = nil
        response = nil
        if let old = peripheral {
            old.delegate = nil
            central?.cancelPeripheralConnection(old)
        }
        peripheral = nil
        selectedDevice = nil
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        ensureCentral()
    }

    func send(_ data: Data) {
        guard ready, let peripheral, peripheral.state == .connected, let command,
              data.count <= peripheral.maximumWriteValueLength(for: .withResponse) else {
            onError?("系统蓝牙配置通道未就绪，请重新检测")
            return
        }
        peripheral.writeValue(data, for: command, type: .withResponse)
    }

    func disconnect() {
        wantsStart = false
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        ready = false
        command = nil
        response = nil
        if let peripheral {
            self.peripheral = nil
            peripheral.delegate = nil
            central?.cancelPeripheralConnection(peripheral)
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
              let restored = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral],
              let candidate = restored.first else { return }
        PhoneFindDiagnostics.record("ble.restored state=\(candidate.state.rawValue)")
        adopt(candidate, restored: true)
    }

    private func handleState(_ state: CBManagerState) {
        guard wantsStart else { return }
        switch state {
        case .poweredOn:
            restoreConnectedPeripheral()
        case .poweredOff:
            connectionTimeout?.invalidate()
            peripheral = nil
            command = nil
            response = nil
            ready = false
            onWaiting?("蓝牙已关闭，开启后会自动恢复连接")
        case .unauthorized:
            onError?("请在系统设置中允许 EasyFind 使用蓝牙")
        case .unsupported:
            onError?("当前设备不支持蓝牙")
        case .resetting:
            onWaiting?("蓝牙正在恢复，稍后会自动检测自拍杆")
        case .unknown:
            break
        @unknown default:
            onError?("蓝牙暂不可用")
        }
    }

    private func restoreConnectedPeripheral() {
        guard wantsStart, peripheral == nil, !ready, let central, central.state == .poweredOn else { return }

        // 这是唯一的设备入口：只取系统已经连接的自定义服务，不扫描附近设备。
        if let connected = central.retrieveConnectedPeripherals(withServices: [serviceUUID]).first {
            adopt(connected)
            return
        }

        // 如果此前已经成功接入过，系统可以按 identifier 找回同一外设；仍不展示设备清单。
        if let raw = UserDefaults.standard.string(forKey: knownPeripheralKey),
           let uuid = UUID(uuidString: raw),
           let remembered = central.retrievePeripherals(withIdentifiers: [uuid]).first {
            adopt(remembered)
            return
        }

        guard !reportedWaiting else { return }
        reportedWaiting = true
        onWaiting?("未检测到系统已连接的自拍杆\n请先在 iPhone“设置 > 蓝牙”中连接设备，返回此页会自动读取")
    }

    private func adopt(_ candidate: CBPeripheral, restored: Bool = false) {
        guard wantsStart else { return }
        reportedWaiting = false
        let name = candidate.name?.isEmpty == false ? candidate.name! : "自拍杆"
        let device = SelfieStickDevice(identifier: candidate.identifier, name: name)
        selectedDevice = device
        peripheral = candidate
        UserDefaults.standard.set(candidate.identifier.uuidString, forKey: knownPeripheralKey)
        command = nil
        response = nil
        ready = false
        candidate.delegate = self
        PhoneFindDiagnostics.record("ble.adopt state=\(candidate.state.rawValue) restored=\(restored)")
        connectionTimeout?.invalidate()
        if restored && candidate.state == .connected {
            discoverServices(on: candidate)
        } else {
            // retrieveConnectedPeripherals describes the SYSTEM connection.
            // Even a connected HID peripheral needs this app's own connection
            // before discovery/subscription and background event delivery.
            central?.connect(candidate, options: nil)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral === self.peripheral else { return }
        PhoneFindDiagnostics.record("ble.connected")
        discoverServices(on: peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        PhoneFindDiagnostics.record("ble.connectFailed error=\(error?.localizedDescription ?? "none")")
        onError?("已连接的自拍杆配置通道不可用，请确认设备支持 EasyFind 协议")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral === self.peripheral else { return }
        PhoneFindDiagnostics.record("ble.disconnected error=\(error?.localizedDescription ?? "none")")
        connectionTimeout?.invalidate()
        self.peripheral = nil
        command = nil
        response = nil
        ready = false
        onDisconnected?()
        // A pending CoreBluetooth connection survives suspension and completes
        // when the known accessory returns; do not cancel it with a UI timer.
        if wantsStart, central.state == .poweredOn { adopt(peripheral) }
    }

    private func discoverServices(on peripheral: CBPeripheral) {
        guard peripheral === self.peripheral else { return }
        connectionTimeout?.invalidate()
        connectionTimeout = Timer.scheduledTimer(withTimeInterval: 12, repeats: false) { [weak self] _ in
            PhoneFindDiagnostics.record("ble.discoveryTimeout")
            self?.onError?("系统蓝牙已连接，但自拍杆配置通道响应超时")
        }
        peripheral.discoverServices([serviceUUID])
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard peripheral === self.peripheral else { return }
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }) else {
            onError?("设备不支持当前自拍杆配置服务")
            return
        }
        peripheral.discoverCharacteristics([commandUUID, responseUUID], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard peripheral === self.peripheral else { return }
        command = service.characteristics?.first(where: { $0.uuid == commandUUID })
        response = service.characteristics?.first(where: { $0.uuid == responseUUID })
        guard error == nil, let command, command.properties.contains(.write),
              let response, response.properties.contains(.notify) else {
            onError?("设备缺少自拍杆配置或通知通道")
            return
        }
        peripheral.setNotifyValue(true, for: response)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic.uuid == responseUUID else { return }
        guard error == nil, characteristic.isNotifying, command != nil, let selectedDevice else {
            onError?("无法接收自拍杆确认，请检查系统蓝牙连接")
            return
        }
        connectionTimeout?.invalidate()
        connectionTimeout = nil
        ready = true
        PhoneFindDiagnostics.record("ble.subscribed")
        onReady?(selectedDevice)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic.uuid == responseUUID else { return }
        guard error == nil, let data = characteristic.value else {
            onError?("自拍杆回复读取失败")
            return
        }
        PhoneFindDiagnostics.record("ble.frame bytes=\(data.count)")
        onFrame?(data)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral === self.peripheral, characteristic.uuid == commandUUID else { return }
        if error != nil { onError?("自拍杆设置发送失败，请重新检测") }
        // 无错误仅表示 ATT 写入完成；保存状态由独立回复报文确认。
    }
}

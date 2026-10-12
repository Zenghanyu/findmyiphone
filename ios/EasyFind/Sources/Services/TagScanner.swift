import CoreBluetooth

/// 一次扫描到的 Tag 快照。
/// A snapshot of one discovered tag.
struct ScannedTag {
    /// `peripheral.identifier.uuidString.lowercased()`，与 SDK/上层统一的小写地址。
    let address: String
    /// 广播名（广告包 LocalName 优先，回退到 peripheral.name）。
    let name: String
    let rssi: Int
    /// 真实 BLE 外设；模拟器 Mock 模式下为 `nil`。
    let peripheral: CBPeripheral?
    let lastSeenAt: Date
}

/// 精简 BLE 扫描器：发现 EasyFind UWB 标签并按需连接。
///
/// 从 UWBSeek Runner 的 `TagMonitorService` 提取扫描/连接核心，去掉后台监控、
/// 离开提醒、Find My 同步等 EasyFind 单页版不再需要的逻辑。
///
/// Minimal BLE scanner: discovers EasyFind UWB tags and connects on demand.
final class TagScanner: NSObject, CBCentralManagerDelegate {

    static let shared = TagScanner()

    // MARK: - 服务 UUID（与 UWBSeek 一致）
    /// 主 NI accessory 服务。
    static let niServiceUUID = CBUUID(string: "00002761-08C2-11E1-9073-0E8AC72E1001")
    /// 备选 NI accessory 服务（Android NI accessory server）。
    static let altServiceUUID = CBUUID(string: "48FE3E40-0817-4BB2-8633-3073689C2DBA")
    /// Beacon 板服务。
    static let beaconServiceUUID = CBUUID(string: "00002760-08C2-11E1-9073-0E8AC72E1001")

    private static let knownUUIDs: [CBUUID] = [
        niServiceUUID, altServiceUUID, beaconServiceUUID
    ]

    private(set) var centralManager: CBCentralManager!
    private var discovered: [String: ScannedTag] = [:]
    private var pendingConnects: [UUID: (Result<CBPeripheral, Error>) -> Void] = [:]

    /// 蓝牙状态变化（主线程回调）。
    var onBluetoothStateChanged: ((CBManagerState) -> Void)?
    /// 发现已知服务 UUID 的标签。
    var onDiscovered: ((ScannedTag) -> Void)?
    /// 已连接外设断开。
    var onDisconnected: ((CBPeripheral) -> Void)?

    private override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    var isScanning: Bool { centralManager.isScanning }
    var bluetoothState: CBManagerState { centralManager.state }

    // MARK: - 扫描

    /// 开始发现模式扫描：不过滤服务（允许发现所有广告），回调中按已知 UUID 过滤。
    /// 与 UWBSeek `setDiscoveryMode(true)` 行为一致。
    func startDiscoveryScan() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
    }

    /// 停止扫描。
    func stopScan() {
        guard centralManager.isScanning else { return }
        centralManager.stopScan()
    }

    // MARK: - 连接

    func connect(_ peripheral: CBPeripheral, completion: @escaping (Result<CBPeripheral, Error>) -> Void) {
        pendingConnects[peripheral.identifier] = completion
        centralManager.connect(peripheral, options: nil)
    }

    func disconnect(_ peripheral: CBPeripheral) {
        guard centralManager.state == .poweredOn else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        onBluetoothStateChanged?(central.state)
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        let hasKnownService = !serviceUUIDs.isEmpty
            && serviceUUIDs.contains(where: { Self.knownUUIDs.contains($0) })
        guard hasKnownService else { return }

        let address = peripheral.identifier.uuidString.lowercased()
        let advName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advName ?? peripheral.name ?? "EasyFind Tag"
        let tag = ScannedTag(
            address: address,
            name: name,
            rssi: RSSI.intValue,
            peripheral: peripheral,
            lastSeenAt: Date()
        )
        discovered[address] = tag
        onDiscovered?(tag)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let completion = pendingConnects.removeValue(forKey: peripheral.identifier)
        completion?(.success(peripheral))
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        let completion = pendingConnects.removeValue(forKey: peripheral.identifier)
        completion?(.failure(error ?? NSError(domain: "TagScanner", code: -1,
                                              userInfo: [NSLocalizedDescriptionKey: "连接失败"])))
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        onDisconnected?(peripheral)
    }
}

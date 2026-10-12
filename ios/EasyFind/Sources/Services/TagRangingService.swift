import CoreBluetooth
import FindMyTagKit

/// 原生测距服务：管理 BLE 连接池与 `RangingSession` 生命周期。
///
/// 从 UWBSeek Runner 的 `FlutterTagBridge` 提取纯 Swift 逻辑（连接池、keepalive、
/// 会话按需创建、GATT ready 自动起测），剥离 Flutter messenger 依赖，
/// 供 EasyFind 原生单页界面使用。
@MainActor
final class TagRangingService {

    static let shared = TagRangingService()

    /// 一条已建立的 BLE 连接（transport + keepalive）。
    struct Connection {
        let peripheral: CBPeripheral
        let transport: CoreBluetoothTransport
        let keepalive: BleKeepalivePolicy
    }

    // MARK: - 状态

    private var bleConnections: [String: Connection] = [:]
    private var rangingSessions: [String: RangingSession] = [:]
    private var pendingConnectAddresses = Set<String>()
    private var pendingConnectCompletions: [String: [(@MainActor (Bool) -> Void)]] = [:]

    /// 会话状态回调（address → state）。
    var onSessionState: ((String, SessionState) -> Void)?
    /// 测距数据回调（address → measurement）。
    var onMeasurement: ((String, RangingMeasurement) -> Void)?
    /// SDK 调试日志回调。
    var onDebugLog: ((String) -> Void)?

    private let sdk: FindMyTagSDK

    private init() {
        let config = FindMyTagSDK.Config(
            // 相机辅助开启（NISession 内部 world tracking，方位角稳定），
            // 粒子滤波关闭（1000 粒子在主线程每 50ms 更新，会占满主线程导致
            // 按钮无响应；UI 只用原始 distance/azimuth，不消费融合输出）。
            enableARFusion: false,
            enableCameraAssistance: true,
            externalARSession: nil,
            watchdogConfig: .default,
            enableChipAuthentication: false
        )
        sdk = FindMyTagSDK(config: config)
    }

    var connectedAddresses: [String] { Array(bleConnections.keys) }
    func isConnected(address: String) -> Bool { bleConnections[address] != nil }

    // MARK: - BLE 连接池

    /// 建立带 keepalive 的持久 BLE 连接。连接失败时 keepalive 会无限期后台重连。
    /// 不创建 RangingSession——由 `session(address:autoStartRanging:)` 按需创建。
    func connect(peripheral: CBPeripheral, address: String,
                 completion: @escaping @MainActor (Bool) -> Void) {
        guard bleConnections[address] == nil else {
            completion(true)
            return
        }
        // 防止同地址并发连接竞态
        guard !pendingConnectAddresses.contains(address) else {
            pendingConnectCompletions[address, default: []].append(completion)
            return
        }
        pendingConnectAddresses.insert(address)

        let keepalive = BleKeepalivePolicy(
            centralManager: TagScanner.shared.centralManager,
            peripheral: peripheral
        )
        keepalive.connectHandler = { p, done in
            TagScanner.shared.connect(p, completion: done)
        }
        keepalive.onReconnected = { [weak self, weak keepalive] reconnectedPeripheral in
            guard let self, let keepalive, !keepalive.isClosed else { return }
            self.replaceTransportForReconnect(address: address, peripheral: reconnectedPeripheral)
        }

        TagScanner.shared.connect(peripheral) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else {
                    keepalive.close()
                    completion(false)
                    return
                }
                self.pendingConnectAddresses.remove(address)
                let waiters = self.pendingConnectCompletions.removeValue(forKey: address) ?? []
                switch result {
                case .success(let connectedPeripheral):
                    let transport = CoreBluetoothTransport(peripheral: connectedPeripheral)
                    self.bleConnections[address] = Connection(
                        peripheral: connectedPeripheral,
                        transport: transport,
                        keepalive: keepalive
                    )
                    completion(true)
                    for waiter in waiters { waiter(true) }
                case .failure:
                    // 初始连接失败：keepalive 重试接管
                    keepalive.onDisconnected()
                    completion(false)
                    for waiter in waiters { waiter(false) }
                }
            }
        }
    }

    /// keepalive 重连成功后：换新 transport，恢复会话。
    private func replaceTransportForReconnect(address: String, peripheral: CBPeripheral) {
        if let existing = bleConnections[address] {
            existing.transport.close()
        }
        let newTransport = CoreBluetoothTransport(peripheral: peripheral)
        bleConnections[address] = Connection(
            peripheral: peripheral,
            transport: newTransport,
            keepalive: bleConnections[address]?.keepalive ?? BleKeepalivePolicy(
                centralManager: TagScanner.shared.centralManager,
                peripheral: peripheral
            )
        )
        if let session = rangingSessions[address] {
            session.replaceTransport(newTransport)
            session.resume()
            session.startRanging()
        }
    }

    // MARK: - RangingSession

    /// 返回既有会话，或从连接池创建新会话。
    /// - Parameter autoStartRanging: true 时 GATT ready 自动 startRanging（精准查找场景）。
    private func getOrCreateSession(address: String, autoStartRanging: Bool = false) -> RangingSession? {
        if let session = rangingSessions[address] {
            if autoStartRanging {
                wireGattReadyAutoStart(address: address, session: session)
            }
            return session
        }
        guard let conn = bleConnections[address] else { return nil }
        // BLE 可能刚断开：死 transport 上建会话会立即 OOB 失败
        guard conn.peripheral.state == .connected else { return nil }
        let session = sdk.createSession(transport: conn.transport)
        session.debugLogHandler = { [weak self] msg in
            self?.onDebugLog?(msg)
        }
        if autoStartRanging {
            wireGattReadyAutoStart(address: address, session: session)
        }
        rangingSessions[address] = session
        return session
    }

    /// GATT 就绪后自动 startRanging（已就绪会立即触发）。
    private func wireGattReadyAutoStart(address: String, session: RangingSession) {
        guard let conn = bleConnections[address] else { return }
        conn.transport.onGattReady = { [weak session] in
            DispatchQueue.main.async {
                session?.startRanging()
            }
        }
    }

    /// 启动精准测距：优先复用连接池中的会话；无连接则连接后创建。
    /// `startRanging()` 延迟到 GATT ready 触发。
    func startRanging(address: String, peripheral: CBPeripheral?,
                      completion: @escaping (RangingSession?) -> Void) {
        if let session = getOrCreateSession(address: address, autoStartRanging: true) {
            wireHandlers(session: session, address: address)
            completion(session)
            return
        }
        guard let peripheral else {
            completion(nil)
            return
        }
        connect(peripheral: peripheral, address: address) { [weak self] success in
            guard let self else { return }
            guard success, let session = self.getOrCreateSession(address: address, autoStartRanging: true) else {
                completion(nil)
                return
            }
            self.wireHandlers(session: session, address: address)
            completion(session)
        }
    }

    /// 转发会话回调到服务级闭包。
    private func wireHandlers(session: RangingSession, address: String) {
        session.stateHandler = { [weak self] state in
            self?.onSessionState?(address, state)
        }
        session.rangingHandler = { [weak self] m in
            self?.onMeasurement?(address, m)
        }
    }

    /// 停止测距（保留 BLE 连接）。
    func stopRanging(address: String) {
        rangingSessions[address]?.stopRanging()
    }

    /// 停止全部测距。
    func stopAllRanging() {
        for session in rangingSessions.values {
            session.stopRanging()
        }
    }

    // MARK: - 配件指令

    func playSound(address: String, completion: ((Bool) -> Void)? = nil) {
        if let session = rangingSessions[address] {
            do {
                try session.playSound()
                completion?(true)
            } catch {
                completion?(false)
            }
            return
        }
        guard let conn = bleConnections[address] else {
            completion?(false)
            return
        }
        let session = sdk.createSession(transport: conn.transport)
        rangingSessions[address] = session
        do {
            try session.playSound()
            completion?(true)
        } catch {
            completion?(false)
        }
    }

    func stopSound(address: String) {
        do { try rangingSessions[address]?.stopSound() } catch {}
    }

    // MARK: - 断开

    func disconnect(address: String) {
        rangingSessions[address]?.stopRanging()
        rangingSessions.removeValue(forKey: address)
        guard let conn = bleConnections.removeValue(forKey: address) else { return }
        conn.keepalive.close()
        conn.transport.signalClosed()
        conn.transport.close()
        TagScanner.shared.disconnect(conn.peripheral)
    }

    func disconnectAll() {
        for address in Array(bleConnections.keys) {
            disconnect(address: address)
        }
    }
}

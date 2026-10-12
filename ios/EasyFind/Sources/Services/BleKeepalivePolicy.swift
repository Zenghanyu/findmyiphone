import CoreBluetooth

/// BLE 层连接保活策略。
///
/// BLE 断开后固定 1s 重连，无次数限制，仅 `close()` 终止。
/// 重连成功后通过 `onReconnected` 回调通知上层 replaceTransport。
/// 从 UWBSeek Runner 移植，连接动作通过 `connectHandler` 注入（原实现耦合 TagMonitorService）。
final class BleKeepalivePolicy {
    private let centralManager: CBCentralManager
    private let peripheral: CBPeripheral
    private let reconnectDelay: TimeInterval = 1.0
    private var reconnectTask: Task<Void, Never>?
    private(set) var isClosed = false

    /// 连接执行器：注入 `TagScanner.shared.connect`。
    var connectHandler: ((CBPeripheral, @escaping (Result<CBPeripheral, Error>) -> Void) -> Void)?

    /// 重连成功后调用，上层应创建新 TransportHandle 并 replaceTransport。
    var onReconnecting: (() -> Void)?
    var onReconnected: ((CBPeripheral) -> Void)?

    init(centralManager: CBCentralManager, peripheral: CBPeripheral) {
        self.centralManager = centralManager
        self.peripheral = peripheral
    }

    func onDisconnected() {
        guard !isClosed else { return }
        cancelReconnect()
        onReconnecting?()
        scheduleReconnect()
    }

    func onConnected(with reconnectedPeripheral: CBPeripheral? = nil) {
        guard !isClosed else { return }
        cancelReconnect()
        onReconnected?(reconnectedPeripheral ?? peripheral)
    }

    func close() {
        isClosed = true
        cancelReconnect()
    }

    private func scheduleReconnect() {
        reconnectTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .seconds(self.reconnectDelay))
            guard !Task.isCancelled, !self.isClosed else { return }
            await MainActor.run {
                guard !self.isClosed else { return }
                guard self.centralManager.state == .poweredOn else {
                    self.scheduleReconnect()
                    return
                }
                guard let connect = self.connectHandler else {
                    self.scheduleReconnect()
                    return
                }
                connect(self.peripheral) { [weak self] result in
                    guard let self, !self.isClosed else { return }
                    switch result {
                    case .success(let reconnectedPeripheral):
                        self.onConnected(with: reconnectedPeripheral)
                    case .failure:
                        self.scheduleReconnect()
                    }
                }
            }
        }
    }

    private func cancelReconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
    }
}

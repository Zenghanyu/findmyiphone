#if targetEnvironment(simulator)
import Foundation

/// 模拟固件，与 App 使用相同编解码。UserDefaults 在模拟器中代替设备 Flash。
/// 此类不进入真机产物；演示计时不能证明 App 退出后的真实硬件行为。
final class SelfieStickDemoTransport: SelfieStickTransport {
    var onReady: ((SelfieStickDevice) -> Void)?
    var onFrame: ((Data) -> Void)?
    var onDisconnected: (() -> Void)?
    var onError: ((String) -> Void)?
    var onWaiting: ((String) -> Void)?

    private let device = SelfieStickDevice(identifier: UUID(uuidString: "452451DA-F077-4D75-83E1-BED97021747F")!,
                                           name: "EasyFind 自拍杆")
    private let flashKey = "SelfieStickDemo.v1.persistedDelay"
    private var delay: UInt8 = 3
    private var connected = false
    private var generation = UUID()
    private var countdown: Timer?
    private var deadline: TimeInterval?
    private var lastRemaining: Int?

    init() {
        if ProcessInfo.processInfo.arguments.contains("-selfieReset") {
            UserDefaults.standard.removeObject(forKey: flashKey)
        }
        let stored = UserDefaults.standard.object(forKey: flashKey) as? Int ?? 3
        delay = UInt8(max(0, min(30, stored)))
    }

    deinit { countdown?.invalidate() }

    /// 模拟设备默认已经在系统蓝牙中连接，页面打开后直接进入 ready。
    func start() { connectAutomatically() }

    func retry() { connectAutomatically() }

    private func connectAutomatically() {
        generation = UUID()
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.generation == token else { return }
            self.connected = true
            self.onReady?(self.device)
        }
    }

    func send(_ data: Data) {
        guard connected, let frame = try? SelfieStickProtocol.Frame.decode(data), frame.sequence != 0 else { return }
        let token = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.connected, self.generation == token else { return }
            switch frame.opcode {
            case .readConfiguration:
                guard frame.payload.isEmpty else { return }
                self.emit(.configuration, sequence: frame.sequence, payload: [0, self.delay, 30, 0x0F])
            case .setDelay:
                guard frame.payload.count == 1 else { return }
                let requested = frame.payload[0]
                let status: UInt8
                if requested > 30 { status = 1 }
                else if self.deadline != nil { status = 4 }
                else if ProcessInfo.processInfo.arguments.contains("-selfieSaveFailure") { status = 3 }
                else { status = 0 }
                if status == 0 {
                    // 先模拟持久化，再回复；UI 不靠本地选项或 ATT 写入回调宣布成功。
                    self.delay = requested
                    UserDefaults.standard.set(Int(requested), forKey: self.flashKey)
                }
                self.emit(.delaySaved, sequence: frame.sequence, payload: [status, self.delay])
            default: break
            }
        }
    }

    func disconnect() {
        countdown?.invalidate()
        countdown = nil
        connected = false
        generation = UUID()
        onDisconnected?()
    }

    func pressPhysicalButton() {
        guard connected else { return }
        if deadline != nil { cancelCountdown(); return }
        if delay == 0 { emitEvent(.shutterSent, remaining: 0); return }
        deadline = ProcessInfo.processInfo.systemUptime + Double(delay)
        lastRemaining = Int(delay)
        emitEvent(.countdownStarted, remaining: delay)
        countdown = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }

    func pressFindPhoneButton() {
        guard connected else { return }
        emitEvent(.phoneFindRequested, remaining: 0)
    }

    func cancelCountdown() {
        guard deadline != nil else { return }
        countdown?.invalidate()
        countdown = nil
        deadline = nil
        lastRemaining = nil
        emitEvent(.countdownCancelled, remaining: 0)
    }

    private func tick() {
        guard let deadline else { return }
        let remaining = max(0, Int(ceil(deadline - ProcessInfo.processInfo.systemUptime)))
        if remaining == 0 {
            countdown?.invalidate()
            countdown = nil
            self.deadline = nil
            lastRemaining = nil
            emitEvent(.shutterSent, remaining: 0)
        } else if remaining != lastRemaining {
            lastRemaining = remaining
            emitEvent(.countdownTick, remaining: UInt8(remaining))
        }
    }

    private func emitEvent(_ event: SelfieStickProtocol.Event, remaining: UInt8) {
        emit(.event, sequence: 0, payload: [event.rawValue, remaining])
    }

    private func emit(_ opcode: SelfieStickProtocol.Opcode, sequence: UInt16, payload: [UInt8]) {
        guard connected, let data = try? SelfieStickProtocol.Frame(opcode: opcode, sequence: sequence, payload: payload).encoded() else { return }
        onFrame?(data)
    }
}
#endif

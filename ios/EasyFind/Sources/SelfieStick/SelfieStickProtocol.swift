import Foundation

/// v0.1 固件协议草案。UUID 和报文均为本项目新定义，尚未由真实硬件实现。
/// HID 快门由设备固件直接发送；本协议只配置设备，不让 App 代替设备计时。
enum SelfieStickProtocol {
    static let serviceUUID = "AEBB1000-7F4A-4A38-8CF0-18D6BB28B273"
    static let commandUUID = "AEBB1001-7F4A-4A38-8CF0-18D6BB28B273"
    static let responseUUID = "AEBB1002-7F4A-4A38-8CF0-18D6BB28B273"
    static let maximumDelay: UInt8 = 30

    enum Opcode: UInt8 {
        case readConfiguration = 0x01
        case setDelay = 0x02
        case configuration = 0x81
        case delaySaved = 0x82
        case event = 0xE0
    }

    enum Event: UInt8 {
        case countdownStarted = 1
        case countdownTick = 2
        case shutterSent = 3
        case countdownCancelled = 4
        /// 自拍杆上的“找手机”按键被按下。App 收到后负责触发手机提醒。
        case phoneFindRequested = 5
    }

    enum ProtocolError: Error, Equatable, LocalizedError {
        case invalidFrame
        case unsupportedVersion
        case invalidDelay
        case invalidReply
        case deviceRejected(UInt8)

        var errorDescription: String? {
            switch self {
            case .invalidFrame: return "设备报文格式不正确"
            case .unsupportedVersion: return "设备协议版本暂不支持"
            case .invalidDelay: return "延时应在 0 至 30 秒之间"
            case .invalidReply: return "设备保存确认与设置不一致，请重新连接读取设置"
            case .deviceRejected(let code):
                switch code {
                case 1: return "设备不接受这个延时时间"
                case 2: return "设备暂不支持延时配置"
                case 3: return "设备保存失败，请重试"
                case 4: return "设备正在倒计时，请稍后设置"
                default: return "设备拒绝了设置，请重试"
                }
            }
        }
    }

    struct Frame: Equatable {
        let opcode: Opcode
        let sequence: UInt16
        let payload: [UInt8]

        /// 7 字节头 + 最多 13 字节负载，兼容默认 ATT MTU 的 20 字节写入。
        func encoded() throws -> Data {
            guard payload.count <= 13 else { throw ProtocolError.invalidFrame }
            return Data([0x53, 0x46, 1, opcode.rawValue,
                         UInt8(sequence & 0xFF), UInt8(sequence >> 8), UInt8(payload.count)] + payload)
        }

        static func decode(_ data: Data) throws -> Frame {
            let bytes = Array(data)
            guard bytes.count >= 7, bytes.count <= 20,
                  bytes[0] == 0x53, bytes[1] == 0x46,
                  bytes.count == 7 + Int(bytes[6]) else { throw ProtocolError.invalidFrame }
            guard bytes[2] == 1 else { throw ProtocolError.unsupportedVersion }
            guard let opcode = Opcode(rawValue: bytes[3]) else { throw ProtocolError.invalidFrame }
            return Frame(opcode: opcode, sequence: UInt16(bytes[4]) | UInt16(bytes[5]) << 8,
                         payload: Array(bytes.dropFirst(7)))
        }
    }

    struct Configuration: Equatable {
        let delay: UInt8
        let maximumDelay: UInt8
        /// bit 0: HID 音量增加键；bit 1: 非易失保存；bit 2: 设备端倒计时；bit 3: 找手机事件。
        let capabilities: UInt8

        var supportsOfflineShutter: Bool { capabilities & 0x07 == 0x07 }
        var supportsPhoneFind: Bool { capabilities & 0x08 == 0x08 }

        func replacingDelay(_ delay: UInt8) -> Configuration {
            Configuration(delay: delay, maximumDelay: maximumDelay, capabilities: capabilities)
        }
    }

    struct Request {
        enum Kind: Equatable { case read; case save(UInt8) }
        let sequence: UInt16
        let kind: Kind

        func encoded() throws -> Data {
            switch kind {
            case .read:
                return try Frame(opcode: .readConfiguration, sequence: sequence, payload: []).encoded()
            case .save(let delay):
                guard delay <= maximumDelay else { throw ProtocolError.invalidDelay }
                return try Frame(opcode: .setDelay, sequence: sequence, payload: [delay]).encoded()
            }
        }

        /// 只接受本次事务的应用层确认。ATT 写入成功不能证明 Flash 已保存。
        /// 无关/迟到的报文返回 nil；设备拒绝、越界或错误回显均不能确认保存成功。
        func confirmedConfiguration(from frame: Frame, current: Configuration?) throws -> Configuration? {
            guard frame.sequence == sequence else { return nil }
            let expected: Opcode = kind == .read ? .configuration : .delaySaved
            guard frame.opcode == expected else { return nil }
            let expectedLength = kind == .read ? 4 : 2
            guard frame.payload.count == expectedLength else { throw ProtocolError.invalidReply }
            guard frame.payload[0] == 0 else { throw ProtocolError.deviceRejected(frame.payload[0]) }
            switch kind {
            case .read:
                let delay = frame.payload[1], maximum = frame.payload[2]
                guard maximum > 0, maximum <= maximumDelay, delay <= maximum else {
                    throw ProtocolError.invalidReply
                }
                return Configuration(delay: delay, maximumDelay: maximum, capabilities: frame.payload[3])
            case .save(let requested):
                guard let current, current.supportsOfflineShutter,
                      requested <= current.maximumDelay, frame.payload[1] == requested else {
                    throw ProtocolError.invalidReply
                }
                return current.replacingDelay(requested)
            }
        }
    }
}

struct SelfieStickDevice: Equatable {
    let identifier: UUID
    let name: String
}

protocol SelfieStickTransport: AnyObject {
    var onReady: ((SelfieStickDevice) -> Void)? { get set }
    var onFrame: ((Data) -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var onWaiting: ((String) -> Void)? { get set }
    /// 只尝试接入系统蓝牙中已经连接的自拍杆，不扫描附近设备，也不提供配对流程。
    func start()
    /// 用户从系统设置完成连接后回到 App，可重新检查一次已连接设备。
    func retry()
    func send(_ data: Data)
    func disconnect()
}

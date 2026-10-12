import CoreBluetooth
import AVFoundation
import NearbyInteraction

/// 权限类型
enum PermissionType {
    case bluetooth
    case camera
}

/// 权限状态
enum PermissionState {
    case authorized
    case notDetermined
    case denied
    case restricted
}

/// 系统就绪状态
struct SystemReadiness {
    let permBluetooth: PermissionState
    let permCamera: PermissionState
    let blePoweredOn: Bool
    let uwbSupported: Bool

    var allReady: Bool {
        permBluetooth == .authorized && permCamera == .authorized && blePoweredOn
    }

    /// 按优先级排列的中文问题列表
    var issues: [String] {
        var result: [String] = []
        if !blePoweredOn             { result.append("蓝牙已关闭") }
        if permBluetooth == .denied  { result.append("蓝牙权限已被拒绝，请在系统设置中开启") }
        if permBluetooth == .restricted { result.append("蓝牙权限已被限制（家长控制等）") }
        if permCamera == .denied     { result.append("相机权限已被拒绝，请在系统设置中开启") }
        if permCamera == .restricted { result.append("相机权限已被限制（家长控制等）") }
        if !uwbSupported             { result.append("此设备不支持 UWB 测距") }
        return result
    }

    /// 需要弹系统授权对话框的权限（notDetermined）
    var requestablePermissions: [PermissionType] {
        var result: [PermissionType] = []
        if permBluetooth == .notDetermined { result.append(.bluetooth) }
        if permCamera == .notDetermined    { result.append(.camera) }
        return result
    }

    /// 是否需要引导用户去系统设置或控制中心（权限被永久拒绝 或 蓝牙已关闭）
    var needsOpenSettings: Bool {
        !blePoweredOn || permBluetooth == .denied || permCamera == .denied
    }
}

/// 权限管理器
final class PermissionManager {

    // MARK: - Check

    static func checkBluetooth() -> PermissionState {
        switch CBCentralManager.authorization {
        case .allowedAlways: return .authorized
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        @unknown default:    return .notDetermined
        }
    }

    static func checkCamera() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:    return .authorized
        case .denied:        return .denied
        case .restricted:    return .restricted
        case .notDetermined: return .notDetermined
        @unknown default:    return .notDetermined
        }
    }

    static func checkUwbSupported() -> Bool {
        NISession.isSupported
    }

    /// 检查系统就绪状态（蓝牙必须由调用方提供 poweredOn 状态）
    static func checkReadiness(blePoweredOn: Bool) -> SystemReadiness {
        SystemReadiness(
            permBluetooth: checkBluetooth(),
            permCamera: checkCamera(),
            blePoweredOn: blePoweredOn,
            uwbSupported: checkUwbSupported()
        )
    }

    // MARK: - Request

    typealias PermissionResult = (PermissionType) -> Void

    /// 请求蓝牙权限：iOS 上创建 CBCentralManager 会自动弹出系统授权对话框。
    /// 调用方需要持有返回的临时 CBCentralManager 直到授权完成。
    static func requestBluetooth(onResult: @escaping (PermissionState) -> Void) -> CBCentralManager {
        let cm = CBCentralManager(delegate: BluetoothAuthDelegate(onResult: onResult),
                                   queue: .main)
        return cm
    }

    /// 请求相机权限
    static func requestCamera(onResult: @escaping (PermissionState) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                onResult(granted ? .authorized : .denied)
            }
        }
    }
}

/// 蓝牙授权专用 delegate：监听 centralManagerDidUpdateState 判断授权是否完成
private final class BluetoothAuthDelegate: NSObject, CBCentralManagerDelegate {
    private let onResult: (PermissionState) -> Void

    init(onResult: @escaping (PermissionState) -> Void) {
        self.onResult = onResult
        super.init()
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state = PermissionManager.checkBluetooth()
        guard state != .notDetermined else { return }
        onResult(state)
    }
}

import Foundation

/// 模拟器 Mock 模式开关（仅 `targetEnvironment(simulator)` 编译进产物，真机零 Mock 代码）。
///
/// 由 UI 测试 / 演示通过 launch arguments 控制：
/// - `-uiMock`：启用 Mock（扫描、Tag 清单、测距、响铃全部走模拟数据）
/// - `-uiMockScenario <name>`：指定异常剧本
///     - `bluetoothOff`：启动即「蓝牙已关闭」错误页
///     - `permissionDenied`：启动即「蓝牙权限未开启」错误页
///     - `rangingFailure`：点击 Tag 后进入 UWB 会话建立失败态
///
/// Simulator-only mock mode. Real devices never contain this code.
#if targetEnvironment(simulator)
enum MockMode {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiMock")
    }

    /// 自动演示模式：启动后自动走完「扫描 → 弹层 → 测距 → 方向丢失 → 就近 → 回 idle」循环。
    static var isAutoplay: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiMockAutoplay")
    }

    enum Scenario: String {
        case bluetoothOff
        case permissionDenied
        case rangingFailure
    }

    static var scenario: Scenario? {
        let args = ProcessInfo.processInfo.arguments
        guard let idx = args.firstIndex(of: "-uiMockScenario"), args.count > idx + 1 else {
            return nil
        }
        return Scenario(rawValue: args[idx + 1])
    }
}
#endif

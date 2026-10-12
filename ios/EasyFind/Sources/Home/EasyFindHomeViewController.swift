import UIKit
import CoreBluetooth
import FindMyTagKit

/// EasyFind 主页面 —— 单页设计（参考 Android 端 Moto Tag App 交互范式）。
///
/// 状态机：
/// - `.idle`：品牌区 + 扫描按钮
/// - `.scanning`：中心扫描动画，发现标签时底部弹出清单面板
/// - `.ranging(address)`：面板收起，中心绘制测距状态（方向箭头 / 距离 / 响铃）
///
/// 整个扫描 → 选择 → 测距流程都在本页面完成，无二级导航。
final class EasyFindHomeViewController: UIViewController {

    enum Phase {
        case idle
        case scanning
        case ranging(String)
        case error(String)
    }

    private var phase: Phase = .idle {
        didSet { applyPhase() }
    }

    // MARK: - Dependencies

    private let scanner = TagScanner.shared
    private let ranging = TagRangingService.shared

    // MARK: - 扫描状态

    private var discoveredTags: [ScannedTag] = []

    // MARK: - 测距状态（移植自 PreciseFindingViewController / Dart PreciseFindingNotifier）

    private var rangingState = PreciseFindingState()
    private let directionFilter = DebounceFilter(riseDelay: 0, fallDelay: 0.8)
    private let nearbyFilter = HysteresisFilter(enterThreshold: 0.55, exitThreshold: 0.80)

    private var lastValidHorizontalAngle: Double?
    private var yawAtLastValidAngle: Double?
    private var currentYaw: Double = 0

    private var currentRangingAddress: String?
    private var currentSession: RangingSession?

    private var soundTimer: Timer?
    private var hapticTimer: Timer?
    private var yawTimer: Timer?
    private var lastUIUpdateTime: CFTimeInterval = 0

    private let mediumGen = UIImpactFeedbackGenerator(style: .medium)

    // MARK: - Mock（仅模拟器编译，真机无此代码）

    #if targetEnvironment(simulator)
    private var mockTagTimer: Timer?
    private var mockRangingTimer: Timer?
    private var mockTagIndex = 0
    private var mockRangingTick = 0
    private let mockTagNames = ["车钥匙", "背包", "雨伞"]
    #endif

    #if targetEnvironment(simulator)
    private var autoplayTimer: Timer?
    /// 自动演示是否仍处于活动状态；用户手动操作后立即停止，防止干扰。
    private var autoplayActive = false
    #endif

    private var mockActive: Bool {
        #if targetEnvironment(simulator)
        return MockMode.isEnabled
        #else
        return false
        #endif
    }

    // MARK: - 视图

    private let brandLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let scanRing = ScanningRingView()
    private let scanHintLabel = UILabel()
    private let motoView = MotoTagRangingView()
    private let distanceLabel = UILabel()
    private let statusLabel = UILabel()
    private let scanButton = UIButton(type: .system)
    private let soundButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

    /// 上次背景色动画目标色（避免每 0.1s 堆积新动画）。
    private var lastBgColorTarget: UIColor?
    /// 上次响铃图标名（避免每 0.1s 无谓刷新 configuration）。
    private var lastSoundIconName: String?
    private let resultsPanel = TagResultsPanelView()
    private var resultsPanelBottom: NSLayoutConstraint!

    /// 蓝牙授权请求保活（仅 notDetermined 阶段）。
    private var authCentral: CBCentralManager?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
        setupBrand()
        setupScanArea()
        setupRangingArea()
        setupButtons()
        setupResultsPanel()
        wireServices()
        applyPhase()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ensureBluetoothReady()
        #if targetEnvironment(simulator)
        if mockActive && MockMode.isAutoplay, case .idle = phase {
            autoplayActive = true
            autoplayTimer?.invalidate()
            autoplayTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
                self?.startScan()
            }
        }
        #endif
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // 页面消失时停止扫描与测距，避免残留会话
        if case .ranging = phase {
            ranging.stopAllRanging()
        }
        scanner.stopScan()
    }

    deinit {
        #if targetEnvironment(simulator)
        autoplayTimer?.invalidate()
        #endif
        yawTimer?.invalidate()
        soundTimer?.invalidate()
        hapticTimer?.invalidate()
        #if targetEnvironment(simulator)
        mockTagTimer?.invalidate()
        mockRangingTimer?.invalidate()
        #endif
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - 蓝牙就绪

    private func ensureBluetoothReady() {
        #if targetEnvironment(simulator)
        if mockActive {
            switch MockMode.scenario {
            case .bluetoothOff:
                phase = .error("蓝牙已关闭，请在控制中心开启蓝牙")
                return
            case .permissionDenied:
                phase = .error("蓝牙权限未开启，请在系统设置中允许 EasyFind 使用蓝牙")
                return
            case .rangingFailure, .none:
                handleBluetoothPowered(.poweredOn)
                return
            }
        }
        #endif
        let btState = PermissionManager.checkBluetooth()
        switch btState {
        case .authorized:
            handleBluetoothPowered(scanner.bluetoothState)
        case .notDetermined:
            authCentral = PermissionManager.requestBluetooth { [weak self] state in
                self?.authCentral = nil
                if state == .authorized {
                    self?.handleBluetoothPowered(self?.scanner.bluetoothState ?? .unknown)
                } else if state == .denied || state == .restricted {
                    self?.phase = .error("蓝牙权限未开启，请在系统设置中允许 EasyFind 使用蓝牙")
                }
            }
        case .denied, .restricted:
            phase = .error("蓝牙权限未开启，请在系统设置中允许 EasyFind 使用蓝牙")
        }
    }

    private func handleBluetoothPowered(_ state: CBManagerState) {
        switch state {
        case .poweredOn:
            if case .error = phase {
                phase = .idle
            }
        case .poweredOff:
            stopScan()
            phase = .error("蓝牙已关闭，请在控制中心开启蓝牙")
        default:
            break
        }
    }

    // MARK: - 服务接线

    private func wireServices() {
        scanner.onDiscovered = { [weak self] tag in
            DispatchQueue.main.async {
                guard let self, case .scanning = self.phase else { return }
                self.discoveredTags.append(tag)
                self.resultsPanel.update(tags: self.discoveredTags)
                self.showResultsPanelIfNeeded()
            }
        }
        scanner.onBluetoothStateChanged = { [weak self] state in
            DispatchQueue.main.async {
                self?.handleBluetoothPowered(state)
            }
        }
        resultsPanel.onSelectTag = { [weak self] tag in
            self?.startRanging(with: tag)
        }
        ranging.onSessionState = { [weak self] address, state in
            DispatchQueue.main.async {
                guard self?.currentRangingAddress == address else { return }
                self?.handleSessionState(state)
            }
        }
        ranging.onMeasurement = { [weak self] address, m in
            DispatchQueue.main.async {
                guard self?.currentRangingAddress == address else { return }
                self?.handleRanging(m)
            }
        }
        ranging.onDebugLog = { msg in
            NSLog("[FindMyTagSDK] %@", msg)
        }
    }

    // MARK: - 扫描控制

    private func startScan() {
        discoveredTags.removeAll()
        resultsPanel.update(tags: [])
        phase = .scanning
        #if targetEnvironment(simulator)
        if mockActive {
            mockTagIndex = 0
            scanRing.startAnimating()
            mockTagTimer?.invalidate()
            mockTagTimer = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self] _ in
                self?.mockDiscoverNextTag()
            }
            return
        }
        #endif
        scanner.startDiscoveryScan()
        scanRing.startAnimating()
    }

    #if targetEnvironment(simulator)
    /// Mock：每 0.6s 发现一个标签，与真实 `onDiscovered` 走同一 UI 路径。
    private func mockDiscoverNextTag() {
        guard mockTagIndex < mockTagNames.count else {
            mockTagTimer?.invalidate()
            mockTagTimer = nil
            return
        }
        let i = mockTagIndex
        mockTagIndex += 1
        let baseRSSI = [-42, -55, -68][i]
        let tag = ScannedTag(
            address: ["C1:23:45:67:89:AB", "C1:23:45:67:89:CD", "C1:23:45:67:89:EF"][i],
            name: mockTagNames[i],
            rssi: baseRSSI + Int.random(in: -6...6),
            peripheral: nil,
            lastSeenAt: Date()
        )
        discoveredTags.append(tag)
        resultsPanel.update(tags: discoveredTags)
        showResultsPanelIfNeeded()
        // 自动演示：第一个标签出现 2s 后自动选中进入测距
        if MockMode.isAutoplay && autoplayActive && i == 0 {
            let first = tag
            autoplayTimer?.invalidate()
            autoplayTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.startRanging(with: first)
            }
        }
    }
    #endif

    private func stopScan() {
        #if targetEnvironment(simulator)
        mockTagTimer?.invalidate()
        mockTagTimer = nil
        #endif
        scanner.stopScan()
        scanRing.stopAnimating()
        hideResultsPanel()
        if case .scanning = phase {
            phase = .idle
        }
    }

    // MARK: - 测距控制

    private func startRanging(with tag: ScannedTag) {
        stopScan()
        hideResultsPanel()
        phase = .ranging(tag.address)
        currentRangingAddress = tag.address
        rangingState = PreciseFindingState()
        directionFilter.reset()
        nearbyFilter.reset()
        lastValidHorizontalAngle = nil
        yawAtLastValidAngle = nil

        #if targetEnvironment(simulator)
        if mockActive {
            mockRangingTick = 0
            mockRangingTimer?.invalidate()
            if MockMode.scenario == .rangingFailure {
                rangingState.presentationState = .failure
                rangingState.errorMessage = "UWB 会话建立失败（模拟）"
                applyRangingStateToUI()
                return
            }
            mockRangingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                self?.mockRangingStep()
            }
            return
        }
        #endif

        ranging.startRanging(address: tag.address, peripheral: tag.peripheral) { [weak self] session in
            DispatchQueue.main.async {
                guard let self, let session else {
                    self?.phase = .error("连接标签失败，请靠近标签后重试")
                    return
                }
                self.currentSession = session
                self.startYawTracking()
                self.applyRangingStateToUI()
            }
        }
    }

    #if targetEnvironment(simulator)
    /// Mock 测距剧本（0.25s/tick）：连接中 → 寻找（箭头旋转+距离下降）→ 方向丢失 → 恢复 → 就在附近。
    /// 数据经 `handleRanging` 走与真机完全相同的状态机与 UI 渲染路径。
    private func mockRangingStep() {
        mockRangingTick += 1
        let tick = mockRangingTick

        // 0. 建立 UWB 连接中（约 1s）
        if tick <= 4 {
            rangingState.presentationState = .preparing
            applyRangingStateToUI()
            return
        }
        // 1. 寻找：距离 5.5→1.2m，箭头 -70°→0°
        if tick <= 20 {
            let t = Double(tick - 4) / 16.0
            let distance = Float(5.5 - 4.3 * t + Double.random(in: -0.25...0.25))
            let azimuth = Float(-70 + 70 * t + Double.random(in: -4...4))
            handleRanging(RangingMeasurement(distance: distance, azimuth: azimuth, elevation: nil))
            return
        }
        // 2. 方向丢失：无角度数据（约 3s，演示 directionLost）
        if tick <= 32 {
            let distance = Float(1.6 + Double.random(in: -0.15...0.15))
            handleRanging(RangingMeasurement(distance: distance, azimuth: nil, elevation: nil))
            return
        }
        // 3. 方向恢复，继续寻找
        if tick <= 40 {
            let distance = Float(1.2 + Double.random(in: -0.2...0.2))
            let azimuth = Float(12 + Double.random(in: -5...5))
            handleRanging(RangingMeasurement(distance: distance, azimuth: azimuth, elevation: nil))
            return
        }
        // 4. 就在附近：持续小范围波动
        let distance = Float(0.4 + Double.random(in: -0.08...0.12))
        let azimuth = Float(Double.random(in: -8...8))
        handleRanging(RangingMeasurement(distance: distance, azimuth: azimuth, elevation: nil))
        // 自动演示：就近态展示约 2s 后结束，回 idle 再循环
        if MockMode.isAutoplay && autoplayActive && tick >= 46 {
            autoplayTimer?.invalidate()
            autoplayTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.endRanging()
            }
        }
    }
    #endif

    private func endRanging() {
        yawTimer?.invalidate()
        yawTimer = nil
        soundTimer?.invalidate()
        hapticTimer?.invalidate()
        #if targetEnvironment(simulator)
        mockRangingTimer?.invalidate()
        mockRangingTimer = nil
        #endif
        if let address = currentRangingAddress {
            // 停止测距并断开 BLE：不断开则首页扫描不到该标签（iOS 扫描不返回已连接外设）
            ranging.disconnect(address: address)
        }
        currentSession = nil
        currentRangingAddress = nil
        phase = .idle
        #if targetEnvironment(simulator)
        if mockActive && MockMode.isAutoplay && autoplayActive {
            autoplayTimer?.invalidate()
            autoplayTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
                self?.startScan()
            }
        }
        #endif
    }

    private func startYawTracking() {
        yawTimer?.invalidate()
        yawTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateYaw()
        }
    }

    private func updateYaw() {
        guard let frame = WorldView.shared?.session.currentFrame else { return }
        currentYaw = Double(frame.camera.eulerAngles.y)
    }

    // MARK: - 会话状态处理（移植自 PreciseFindingViewController）

    private func handleSessionState(_ s: SessionState) {
        if rangingState.presentationState == .directionLost {
            switch s {
            case .ranging: return
            default: break
            }
        }
        switch s {
        case .idle:
            rangingState.presentationState = .scanning
        case .connecting, .oobExchange:
            rangingState.presentationState = .preparing
        case .ranging:
            break
        case .recovering:
            rangingState.presentationState = .scanning
        case .suspended:
            rangingState.presentationState = .suspended
        case .transportLost:
            rangingState.presentationState = .scanning
        case .error(let reason):
            rangingState.errorMessage = "\(reason)"
            rangingState.presentationState = .failure
        }
        applyRangingStateToUI()
    }

    // MARK: - 测距数据处理（移植自 PreciseFindingViewController.handleRanging）

    private func handleRanging(_ m: RangingMeasurement) {
        let distance = Double(m.distance)
        guard distance > 0.01 else { return }

        let azimuth = m.azimuth.map { -Double($0) }
        let alignment = azimuth.map { max(0, min(1, 1 - abs($0) / 90.0)) } ?? 0.0
        let proximity = max(0, min(1, (4.0 - distance) / 3.5))

        let isDirStable = directionFilter.update(azimuth != nil)
        if azimuth != nil {
            lastValidHorizontalAngle = azimuth
            yawAtLastValidAngle = currentYaw
        }

        let isNearby = nearbyFilter.update(distance)

        var newState = rangingState.presentationState
        let ps = rangingState.presentationState

        if ps != .finding && ps != .nearby && ps != .directionLost {
            newState = .finding
        }

        if ps == .finding || ps == .nearby {
            if !isDirStable && rangingState.directionEverAcquired {
                newState = .directionLost
            } else if isNearby {
                newState = .nearby
            } else {
                newState = .finding
            }
        } else if ps == .directionLost {
            if isDirStable {
                newState = .finding
            }
        }

        // IMU dead-reckoning
        let effectiveAngle: Double?
        if azimuth != nil {
            effectiveAngle = azimuth
        } else if let last = lastValidHorizontalAngle, let yawBase = yawAtLastValidAngle {
            let yawDelta = currentYaw - yawBase
            effectiveAngle = last + yawDelta * (180.0 / Double.pi)
        } else {
            effectiveAngle = nil
        }

        if newState == .finding && !rangingState.directionEverAcquired && azimuth != nil {
            rangingState.directionEverAcquired = true
        }
        if newState == .nearby && !rangingState.nearbyAcquired {
            rangingState.nearbyAcquired = true
            hapticTimer?.invalidate()
        }

        rangingState.presentationState = newState
        rangingState.distance = distance
        rangingState.horizontalAngle = effectiveAngle
        rangingState.alignmentProgress = alignment
        rangingState.proximityProgress = proximity

        let now = CACurrentMediaTime()
        if now - lastUIUpdateTime >= 0.1 {
            lastUIUpdateTime = now
            applyRangingStateToUI()
        }
    }

    // MARK: - 测距 UI 刷新

    private func applyRangingStateToUI() {
        let ps = rangingState.presentationState

        // 背景色渐变（接近时背景向浅灰提亮，黑白灰单色）
        let targetColor: UIColor
        if ps == .finding || ps == .nearby {
            targetColor = lerpColor(
                UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1),
                UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1),
                rangingState.greenProgress
            )
        } else {
            targetColor = UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
        }
        // 颜色未变化时不重复启动动画，避免测距回调 10Hz 下动画堆积
        // 拖垮主线程（真机上触摸事件会被饿死）。
        if lastBgColorTarget != targetColor {
            lastBgColorTarget = targetColor
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
                self.view.backgroundColor = targetColor
            }
        }

        let hasAngle = rangingState.horizontalAngle != nil
        motoView.distanceMeters = rangingState.distance
        switch ps {
        case .nearby:
            motoView.mode = .nearby
        case .finding where hasAngle:
            motoView.mode = .finding
            motoView.headingDegrees = rangingState.horizontalAngle ?? 0
        case .directionLost:
            motoView.mode = .directionLost
            if hasAngle {
                motoView.headingDegrees = rangingState.horizontalAngle ?? 0
            }
        case .failure:
            motoView.mode = .failure
        default:
            motoView.mode = .connecting
        }

        switch ps {
        case .scanning:
            distanceLabel.text = ""
            statusLabel.text = ""
        case .preparing:
            distanceLabel.text = ""
            statusLabel.text = ""
        case .ready:
            distanceLabel.text = ""
            statusLabel.text = "已就绪"
        case .finding, .directionLost:
            distanceLabel.text = formatDistance(rangingState.distance)
            statusLabel.text = ps == .directionLost ? "方向丢失，请移动手机" : "沿指示方向寻找"
        case .nearby:
            distanceLabel.text = ""
            statusLabel.text = ""
        case .suspended:
            distanceLabel.text = ""
            statusLabel.text = "已暂停"
        case .failure:
            distanceLabel.text = ""
            statusLabel.text = rangingState.errorMessage ?? "查找失败"
        case .bluetoothUnavailable:
            distanceLabel.text = ""
            statusLabel.text = "蓝牙不可用"
        }

        let showSound = (ps == .finding || ps == .nearby || ps == .directionLost)
        soundButton.isHidden = !showSound
        let iconName = rangingState.isSoundPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill"
        if lastSoundIconName != iconName {
            lastSoundIconName = iconName
            soundButton.configuration?.image = UIImage(systemName: iconName)
        }
    }

    // MARK: - 响铃

    @objc private func toggleSound() {
        #if targetEnvironment(simulator)
        cancelAutoplay()
        #endif
        mediumGen.impactOccurred()
        guard let address = currentRangingAddress else { return }
        #if targetEnvironment(simulator)
        if mockActive {
            if rangingState.isSoundPlaying {
                rangingState.isSoundPlaying = false
            } else {
                rangingState.isSoundPlaying = true
                soundTimer?.invalidate()
                soundTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.rangingState.isSoundPlaying = false
                        self?.applyRangingStateToUI()
                    }
                }
            }
            applyRangingStateToUI()
            return
        }
        #endif
        if rangingState.isSoundPlaying {
            ranging.stopSound(address: address)
            rangingState.isSoundPlaying = false
            soundTimer?.invalidate()
        } else {
            ranging.playSound(address: address) { [weak self] ok in
                DispatchQueue.main.async {
                    guard let self else { return }
                    guard ok else {
                        self.rangingState.isSoundPlaying = false
                        self.statusLabel.text = "无法播放声音，请靠近标签"
                        self.statusLabel.textColor = UIColor(white: 1, alpha: 0.7)
                        self.applyRangingStateToUI()
                        return
                    }
                    self.rangingState.isSoundPlaying = true
                    self.applyRangingStateToUI()  // 立即刷新为播放中图标
                    self.soundTimer?.invalidate()
                    self.soundTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                        DispatchQueue.main.async {
                            self?.rangingState.isSoundPlaying = false
                            self?.applyRangingStateToUI()
                        }
                    }
                }
            }
        }
        applyRangingStateToUI()
    }

    // MARK: - 工具

    private func formatDistance(_ meters: Double?) -> String {
        guard let m = meters else { return "--" }
        if m < 1 { return String(format: "%.0f cm", m * 100) }
        return String(format: "%.1f m", m)
    }

    private func lerpColor(_ a: UIColor, _ b: UIColor, _ t: Double) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(t)
        return UIColor(red: r1 + (r2 - r1) * t,
                       green: g1 + (g2 - g1) * t,
                       blue: b1 + (b2 - b1) * t,
                       alpha: a1 + (a2 - a1) * t)
    }
}

// MARK: - 布局

extension EasyFindHomeViewController {

    private var brandColor: UIColor {
        UIColor(white: 1, alpha: 1) // EasyFind 黑白灰单色系：主按钮白色反色
    }

    private func setupBrand() {
        brandLabel.text = "EasyFind"
        brandLabel.font = .systemFont(ofSize: 26, weight: .bold)
        brandLabel.textColor = .white
        brandLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(brandLabel)

        subtitleLabel.text = "扫描附近的 EasyFind 追踪标签"
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.55)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        NSLayoutConstraint.activate([
            brandLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            brandLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: brandLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupScanArea() {
        scanRing.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanRing)

        scanHintLabel.text = "点击下方按钮开始扫描"
        scanHintLabel.font = .systemFont(ofSize: 15)
        scanHintLabel.textColor = UIColor(white: 1, alpha: 0.6)
        scanHintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanHintLabel)

        NSLayoutConstraint.activate([
            scanRing.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanRing.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            scanRing.widthAnchor.constraint(equalToConstant: 240),
            scanRing.heightAnchor.constraint(equalToConstant: 240),
            scanHintLabel.topAnchor.constraint(equalTo: scanRing.bottomAnchor, constant: 20),
            scanHintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupRangingArea() {
        motoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(motoView)

        distanceLabel.font = .systemFont(ofSize: 52, weight: .bold)
        distanceLabel.textColor = .white
        distanceLabel.textAlignment = .center
        distanceLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(distanceLabel)

        statusLabel.font = .systemFont(ofSize: 16)
        statusLabel.textColor = UIColor(white: 1, alpha: 0.7)
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            motoView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            motoView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            motoView.widthAnchor.constraint(equalToConstant: 260),
            motoView.heightAnchor.constraint(equalToConstant: 260),
            distanceLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            distanceLabel.topAnchor.constraint(equalTo: motoView.bottomAnchor, constant: 40),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: distanceLabel.bottomAnchor, constant: 8),
        ])
    }

    private func setupButtons() {
        scanButton.configuration = makePrimaryButton(title: "扫描标签", symbol: "wave.3.right")
        scanButton.addTarget(self, action: #selector(scanTapped), for: .touchUpInside)
        scanButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanButton)

        soundButton.configuration = makeIconButton(symbol: "speaker.slash.fill")
        soundButton.accessibilityLabel = "响铃"
        soundButton.addTarget(self, action: #selector(toggleSound), for: .touchUpInside)
        soundButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(soundButton)

        stopButton.configuration = makeIconButton(symbol: "xmark")
        stopButton.accessibilityLabel = "结束"
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        stopButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stopButton)

        NSLayoutConstraint.activate([
            scanButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            scanButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            scanButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -28),
            scanButton.heightAnchor.constraint(equalToConstant: 56),

            stopButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            stopButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stopButton.widthAnchor.constraint(equalToConstant: 46),
            stopButton.heightAnchor.constraint(equalToConstant: 46),

            soundButton.topAnchor.constraint(equalTo: stopButton.bottomAnchor, constant: 12),
            soundButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            soundButton.widthAnchor.constraint(equalToConstant: 46),
            soundButton.heightAnchor.constraint(equalToConstant: 46),
        ])
    }

    private func makePrimaryButton(title: String, symbol: String) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 8
        config.cornerStyle = .capsule
        config.baseBackgroundColor = brandColor
        config.baseForegroundColor = UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 17, weight: .semibold)
            return out
        }
        return config
    }

    private func makeIconButton(symbol: String) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.image = UIImage(systemName: symbol)
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(white: 1, alpha: 0.12)
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        return config
    }

    private func makeSecondaryButton(title: String, symbol: String) -> UIButton.Configuration {
        var config = UIButton.Configuration.filled()
        config.title = title
        config.image = UIImage(systemName: symbol)
        config.imagePadding = 6
        config.cornerStyle = .capsule
        config.baseBackgroundColor = UIColor(white: 1, alpha: 0.12)
        config.baseForegroundColor = .white
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var out = incoming
            out.font = .systemFont(ofSize: 16, weight: .medium)
            return out
        }
        return config
    }

    private func setupResultsPanel() {
        resultsPanel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultsPanel)
        resultsPanelBottom = resultsPanel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 360)
        NSLayoutConstraint.activate([
            resultsPanel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            resultsPanel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            resultsPanel.heightAnchor.constraint(equalToConstant: min(360, view.bounds.height * 0.45)),
            resultsPanelBottom,
        ])
        resultsPanel.alpha = 0
    }

    private func showResultsPanelIfNeeded() {
        guard resultsPanelBottom.constant != 0 else { return }
        resultsPanelBottom.constant = 0
        resultsPanel.alpha = 1
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.view.layoutIfNeeded()
        }
    }

    private func hideResultsPanel() {
        // 面板显示时 bottom 约束 constant 为 0；仅显示状态需要收起
        guard resultsPanelBottom.constant == 0 else { return }
        resultsPanelBottom.constant = 360
        resultsPanel.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseIn) {
            self.view.layoutIfNeeded()
        }
    }

    // MARK: - 阶段切换

    private func applyPhase() {
        guard isViewLoaded else { return }
        switch phase {
        case .idle:
            scanRing.isHidden = false
            scanHintLabel.isHidden = false
            scanHintLabel.text = "点击下方按钮开始扫描"
            motoView.isHidden = true
            distanceLabel.isHidden = true
            statusLabel.isHidden = true
            scanButton.isHidden = false
            soundButton.isHidden = true
            stopButton.isHidden = true
            scanButton.configuration?.title = "扫描标签"
            scanButton.configuration?.image = UIImage(systemName: "wave.3.right")
        case .scanning:
            scanRing.isHidden = false
            scanHintLabel.isHidden = false
            scanHintLabel.text = "正在扫描附近标签…"
            motoView.isHidden = true
            distanceLabel.isHidden = true
            statusLabel.isHidden = true
            scanButton.isHidden = false
            soundButton.isHidden = true
            stopButton.isHidden = true
            scanButton.configuration?.title = "停止扫描"
            scanButton.configuration?.image = UIImage(systemName: "stop.fill")
        case .ranging:
            scanRing.isHidden = true
            scanHintLabel.isHidden = true
            motoView.isHidden = false
            distanceLabel.isHidden = false
            statusLabel.isHidden = false
            scanButton.isHidden = true
            soundButton.isHidden = true
            stopButton.isHidden = false
            // 响铃按钮在 applyRangingStateToUI 中按测距状态显示
        case .error(let message):
            scanRing.isHidden = true
            scanHintLabel.isHidden = false
            scanHintLabel.text = message
            motoView.isHidden = true
            distanceLabel.isHidden = true
            statusLabel.isHidden = true
            scanButton.isHidden = false
            soundButton.isHidden = true
            stopButton.isHidden = true
            scanButton.configuration?.title = "重试"
            scanButton.configuration?.image = UIImage(systemName: "arrow.clockwise")
        }
    }

    // MARK: - Actions

    /// 用户手动操作时立即取消自动演示循环，避免自动流程干扰手动交互。
    #if targetEnvironment(simulator)
    private func cancelAutoplay() {
        autoplayActive = false
        autoplayTimer?.invalidate()
        autoplayTimer = nil
    }
    #endif

    @objc private func scanTapped() {
        #if targetEnvironment(simulator)
        cancelAutoplay()
        #endif
        switch phase {
        case .scanning:
            stopScan()
        case .error, .idle:
            ensureBluetoothReady()
            startScan()
        default:
            break
        }
    }

    @objc private func stopTapped() {
        #if targetEnvironment(simulator)
        cancelAutoplay()
        #endif
        mediumGen.impactOccurred()
        endRanging()
    }
}

// MARK: - 扫描动画圆环

/// 扫描中的旋转虚线圆环动画。
/// Google Find My Device 风格扫描指示：波浪形变环 + 声呐扩散波纹 + 中心脉冲点。
final class ScanningRingView: UIView {
    private let waveLayer = CAShapeLayer()       // 白色波浪形变环
    private let echoLayers: [CAShapeLayer]       // 从中心扩散的波纹
    private let centerDot = CALayer()
    private var displayLink: CADisplayLink?
    private var phase: CGFloat = 0
    private var echoPhase: CGFloat = 0

    private let brandColor = UIColor(white: 1, alpha: 1)

    override init(frame: CGRect) {
        var echoes: [CAShapeLayer] = []
        for i in 0..<2 {
            let l = CAShapeLayer()
            l.fillColor = UIColor.clear.cgColor
            l.strokeColor = brandColor.withAlphaComponent(0.0).cgColor
            l.lineWidth = 2
            echoes.append(l)
        }
        echoLayers = echoes

        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear

        waveLayer.fillColor = UIColor.clear.cgColor
        waveLayer.strokeColor = brandColor.cgColor
        waveLayer.lineWidth = 3
        waveLayer.lineCap = .round
        layer.addSublayer(waveLayer)
        echoLayers.forEach { layer.addSublayer($0) }

        centerDot.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)
        centerDot.cornerRadius = 5
        centerDot.backgroundColor = brandColor.cgColor
        layer.addSublayer(centerDot)
        drawWave(phase: 0)
        drawEchoes(progress: 0)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        waveLayer.frame = bounds
        echoLayers.forEach { $0.frame = bounds }
        centerDot.position = CGPoint(x: bounds.midX, y: bounds.midY)
        drawWave(phase: phase)
        drawEchoes(progress: echoPhase)
    }

    /// 波形圆环：半径随角度正弦扰动，相位旋转即产生波浪沿圆周流动的形变。
    private func wavePath(radius: CGFloat, amplitude: CGFloat, waves: Int, phase: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        let steps = 120
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for i in 0...steps {
            let theta = CGFloat(i) / CGFloat(steps) * 2 * .pi
            let r = radius * (1 + amplitude * sin(CGFloat(waves) * theta + phase))
            let pt = CGPoint(x: center.x + r * cos(theta), y: center.y + r * sin(theta))
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.close()
        return path
    }

    private func drawWave(phase: CGFloat) {
        let radius = (min(bounds.width, bounds.height) / 2) - 10
        waveLayer.path = wavePath(radius: radius, amplitude: 0.07, waves: 6, phase: phase).cgPath
        waveLayer.opacity = 0.9
    }

    private func drawEchoes(progress: CGFloat) {
        let maxR = (min(bounds.width, bounds.height) / 2) - 14
        for (i, l) in echoLayers.enumerated() {
            let p = (progress + CGFloat(i) * 0.5).truncatingRemainder(dividingBy: 1)
            let r = 14 + p * maxR
            let path = UIBezierPath(ovalIn: CGRect(x: bounds.midX - r, y: bounds.midY - r,
                                                   width: r * 2, height: r * 2))
            l.path = path.cgPath
            l.strokeColor = brandColor.withAlphaComponent((1 - p) * 0.45).cgColor
        }
    }

    func startAnimating() {
        guard displayLink == nil else { return }
        phase = 0
        echoPhase = 0
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stopAnimating() {
        displayLink?.invalidate()
        displayLink = nil
        drawWave(phase: 0)
        drawEchoes(progress: 0)
        centerDot.opacity = 1
    }

    @objc private func tick() {
        phase += 0.05
        echoPhase += 0.014
        drawWave(phase: phase)
        drawEchoes(progress: echoPhase)
        centerDot.opacity = Float(0.4 + 0.6 * (0.5 + 0.5 * sin(phase * 1.6)))
    }
}

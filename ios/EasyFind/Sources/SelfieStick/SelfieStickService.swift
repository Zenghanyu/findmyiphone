import AudioToolbox
import AVFoundation
import UIKit
import Foundation
import UserNotifications
import AlarmKit
import SwiftUI

/// 自拍杆业务层。
///
/// 自拍杆的系统蓝牙配对由 iOS 设置完成。这里不会扫描附近设备，也不会让用户在 App
/// 内选择设备；初始化后只读取系统当前已经连接的配置服务。延时保存成功的唯一依据仍
/// 是设备返回的应用层确认帧。
final class SelfieStickService {
    static let shared = SelfieStickService()
    enum Phase: Equatable {
        case waiting
        case connecting
        case reading
        case ready
        case failed
    }

    let isDemo: Bool
    private let transport: SelfieStickTransport
    private(set) var phase: Phase = .waiting
    private(set) var device: SelfieStickDevice?
    private(set) var configuration: SelfieStickProtocol.Configuration?
    private(set) var message: String?
    private(set) var messageIsError = false
    private(set) var isSaving = false
    private(set) var countdownRemaining: Int?
    private(set) var shotCount = 0
    private(set) var demoResult: String?
    private(set) var phoneFindCount = 0
    private(set) var lastPhoneFindAt: Date?
    var onChange: (() -> Void)?
    private(set) var phoneFindAuthorized = false
    private(set) var phoneFindAuthorizationDenied = false
    private(set) var isPhoneFindAlerting = false
    private(set) var isPhoneFindScheduling = false
    private(set) var phoneFindError: String?
    var usesSystemAlarm: Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }
    private(set) var phoneFindSoundEnabled = UserDefaults.standard.object(forKey: "EasyFind.phoneFindSound") as? Bool ?? true

    private var sequence = UInt16.random(in: 1...UInt16.max)
    private var pending: SelfieStickProtocol.Request?
    private var timeout: Timer?
    @MainActor private lazy var phoneFindDelivery = PhoneFindDelivery(store: .applicationStore())
    private var lastPhoneFindRequestID: UInt64?

    init() {
        PhoneFindDiagnostics.record("service.start")
        #if targetEnvironment(simulator)
        if MockMode.isEnabled || ProcessInfo.processInfo.arguments.contains("-selfieDemo") {
            transport = SelfieStickDemoTransport()
            isDemo = true
        } else {
            transport = SelfieStickBluetoothTransport()
            isDemo = false
        }
        #else
        transport = SelfieStickBluetoothTransport()
        isDemo = false
        #endif
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-selfieReset") {
            phoneFindSoundEnabled = true
            UserDefaults.standard.removeObject(forKey: "EasyFind.phoneFindSound")
        }
        #endif
        if #available(iOS 26.0, *), !isDemo {
            Task { @MainActor [weak self] in
                PhoneFindAlarmController.shared.onChange = { [weak self] pending, alerting, error in
                    guard let self else { return }
                    self.isPhoneFindScheduling = pending
                    self.isPhoneFindAlerting = alerting
                    self.phoneFindError = error
                    self.onChange?()
                }
                self?.refreshPhoneFindAuthorization()
            }
        } else {
            refreshPhoneFindAuthorization()
        }
        wireTransport()
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        // 两个主窗口共用这一份服务。即使用户停留在“查找”页，后台的找手机事件仍能到达。
        transport.start()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        timeout?.invalidate()
        transport.disconnect()
    }

    @objc private func didEnterBackground() {
        PhoneFindDiagnostics.record("lifecycle.background phase=\(phase)")
    }

    @objc private func didBecomeActive() {
        PhoneFindDiagnostics.record("lifecycle.active phase=\(phase)")
        refreshPhoneFindAuthorization()
        if phase == .waiting || phase == .failed { retry() }
    }

    /// 从系统蓝牙重新读取已经连接的自拍杆。这里不扫描、不展示设备清单。
    func retry() {
        guard phase != .ready, phase != .connecting, phase != .reading else { return }
        clearPending()
        configuration = nil
        countdownRemaining = nil
        message = nil
        messageIsError = false
        phase = .connecting
        onChange?()
        transport.retry()
    }

    func save(delay: Int) {
        guard phase == .ready, pending == nil, let configuration,
              configuration.supportsOfflineShutter,
              (0...Int(configuration.maximumDelay)).contains(delay), countdownRemaining == nil else { return }
        message = "正在等待设备保存确认…"
        messageIsError = false
        isSaving = true
        sendRequest(kind: .save(UInt8(delay)))
    }

    func pressDemoButton() {
        #if targetEnvironment(simulator)
        guard phase == .ready, !isSaving else { return }
        demoResult = nil
        (transport as? SelfieStickDemoTransport)?.pressPhysicalButton()
        #endif
    }

    func cancelDemoCountdown() {
        #if targetEnvironment(simulator)
        (transport as? SelfieStickDemoTransport)?.cancelCountdown()
        #endif
    }

    func pressDemoFindPhone() {
        #if targetEnvironment(simulator)
        (transport as? SelfieStickDemoTransport)?.pressFindPhoneButton()
        #endif
    }

    func requestPhoneFindAuthorization(completion: ((Bool) -> Void)? = nil) {
        if #available(iOS 26.0, *) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                do {
                    let state = try await AlarmManager.shared.requestAuthorization()
                    self.phoneFindAuthorized = state == .authorized
                    self.phoneFindAuthorizationDenied = state == .denied
                    self.phoneFindError = nil
                    PhoneFindDiagnostics.record("alarm.authorization=\(state)")
                } catch {
                    self.phoneFindError = "无法开启系统闹钟，请重试：\(error.localizedDescription)"
                    PhoneFindDiagnostics.record("alarm.authorizationError=\(error.localizedDescription)")
                }
                self.onChange?()
                completion?(self.phoneFindAuthorized)
            }
            return
        }
        PhoneFindNotifier.shared.requestAuthorization { [weak self] granted in
            guard let self else { return }
            self.phoneFindAuthorized = granted
            self.phoneFindAuthorizationDenied = !granted
            self.onChange?()
            completion?(granted)
        }
    }

    func repeatDemoFindPhoneRequest() {
        #if targetEnvironment(simulator)
        (transport as? SelfieStickDemoTransport)?.repeatLastFindPhoneRequest()
        #endif
    }

    func refreshPhoneFindAuthorization() {
        #if targetEnvironment(simulator)
        if isDemo && ProcessInfo.processInfo.arguments.contains("-phoneFindAuthorized") {
            phoneFindAuthorized = true
            phoneFindAuthorizationDenied = false
            onChange?()
            return
        }
        if isDemo && ProcessInfo.processInfo.arguments.contains("-phoneFindUnauthorized") {
            phoneFindAuthorized = false
            phoneFindAuthorizationDenied = true
            onChange?()
            return
        }
        #endif
        if #available(iOS 26.0, *) {
            Task { @MainActor [weak self] in
                guard let self else { return }
                let state = AlarmManager.shared.authorizationState
                self.phoneFindAuthorized = state == .authorized
                self.phoneFindAuthorizationDenied = state == .denied
                PhoneFindAlarmController.shared.refresh()
                self.onChange?()
            }
            return
        }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                guard let self else { return }
                self.phoneFindAuthorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
                self.phoneFindAuthorizationDenied = settings.authorizationStatus == .denied
                self.onChange?()
            }
        }
    }

    func savePhoneFindSound(enabled: Bool) {
        phoneFindSoundEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "EasyFind.phoneFindSound")
        if !enabled { stopPhoneFind() }
        onChange?()
    }

    func stopPhoneFind() {
        PhoneFindNotifier.shared.stop()
        if #available(iOS 26.0, *), !isDemo {
            Task { @MainActor in PhoneFindAlarmController.shared.stop() }
            return
        }
        isPhoneFindAlerting = false
        isPhoneFindScheduling = false
        onChange?()
    }

    private func wireTransport() {
        transport.onWaiting = { [weak self] text in
            guard let self else { return }
            self.clearPending()
            self.device = nil
            self.configuration = nil
            self.countdownRemaining = nil
            self.phase = .waiting
            self.message = text
            self.messageIsError = false
            self.onChange?()
        }
        transport.onReady = { [weak self] device in
            guard let self else { return }
            self.device = device
            self.phase = .reading
            self.message = nil
            self.messageIsError = false
            // Opt in before READ_CONFIG. Old firmware ignores 04; new firmware
            // waits for this ordering before releasing any cached button press.
            self.sendControl(.init(opcode: .enableReliablePhoneFind, sequence: self.nextSequence(), payload: []))
            self.sendRequest(kind: .read)
        }
        transport.onFrame = { [weak self] data in self?.receive(data) }
        transport.onError = { [weak self] text in self?.fail(text) }
        transport.onDisconnected = { [weak self] in
            guard let self else { return }
            self.clearPending()
            self.device = nil
            self.configuration = nil
            self.countdownRemaining = nil
            self.phase = .waiting
            self.message = "设备暂时断开，正在等待自动重连"
            self.messageIsError = false
            self.onChange?()
        }
    }

    private func sendRequest(kind: SelfieStickProtocol.Request.Kind) {
        let request = SelfieStickProtocol.Request(sequence: nextSequence(), kind: kind)
        pending = request
        timeout?.invalidate()
        timeout = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.fail("未收到自拍杆确认，请确认系统蓝牙仍已连接")
        }
        onChange?()
        do { transport.send(try request.encoded()) }
        catch { fail(error.localizedDescription) }
    }

    private func nextSequence() -> UInt16 {
        sequence = sequence &+ 1
        if sequence == 0 { sequence = 1 }
        return sequence
    }

    private func sendControl(_ frame: SelfieStickProtocol.Frame) {
        guard let data = try? frame.encoded() else { return }
        transport.send(data)
    }

    private func receive(_ data: Data) {
        do {
            let frame = try SelfieStickProtocol.Frame.decode(data)
            if frame.opcode == .event {
                if let request = SelfieStickProtocol.PhoneFindRequest.decode(frame) {
                    receiveReliablePhoneFind(request)
                    return
                }
                guard frame.sequence == 0, frame.payload.count == 2,
                      frame.payload[1] <= SelfieStickProtocol.maximumDelay,
                      let event = SelfieStickProtocol.Event(rawValue: frame.payload[0]) else { return }
                switch event {
                case .countdownStarted, .countdownTick:
                    countdownRemaining = Int(frame.payload[1])
                case .shutterSent:
                    countdownRemaining = nil
                    shotCount += 1
                    demoResult = isDemo ? "快门已触发（模拟） · 第 \(shotCount) 次" : "设备已发送快门"
                case .countdownCancelled:
                    countdownRemaining = nil
                    demoResult = isDemo ? "倒计时已取消（模拟）" : "倒计时已取消"
                case .phoneFindRequested:
                    Task { @MainActor [weak self] in _ = await self?.submitPhoneFind(requestID: nil) }
                }
                onChange?()
                return
            }
            guard let pending,
                  let confirmed = try pending.confirmedConfiguration(from: frame, current: configuration) else { return }
            let wasSaving = isSaving
            clearPending()
            configuration = confirmed
            phase = .ready
            messageIsError = !confirmed.supportsOfflineShutter
            if !confirmed.supportsOfflineShutter {
                message = "该设备暂不支持保存延时并独立控制相机"
            } else if wasSaving {
                message = isDemo ? "已保存到模拟设备" : "设备已确认保存，关闭 App 后仍可使用"
            } else {
                message = nil
            }
            onChange?()
        } catch let error as SelfieStickProtocol.ProtocolError {
            // Malformed/unknown notifications do not disable background BLE.
            guard error != .invalidFrame, error != .unsupportedVersion else {
                PhoneFindDiagnostics.record("ble.ignoredFrame error=\(error)")
                return
            }
            if case .deviceRejected = error, phase == .ready, isSaving {
                clearPending()
                message = error.localizedDescription
                messageIsError = true
                onChange?()
            } else {
                fail(error.localizedDescription)
            }
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func receiveReliablePhoneFind(_ request: SelfieStickProtocol.PhoneFindRequest) {
        let source = device?.identifier
        Task { @MainActor [weak self] in
            guard let self else { return }
            let result = await self.phoneFindDelivery.receive(request, submit: {
                await self.submitPhoneFind(requestID: request.id)
            }, acknowledge: { disposition in
                // A late system response must not be sent to a different device.
                guard let source, self.device?.identifier == source else { return }
                self.sendControl(request.acknowledgement(sequence: self.nextSequence(), disposition: disposition))
                PhoneFindDiagnostics.record("find.ack disposition=\(disposition.rawValue)")
            })
            PhoneFindDiagnostics.record("find.delivery=\(result)")
        }
    }

    @MainActor
    private func submitPhoneFind(requestID: UInt64?) async -> SelfieStickProtocol.PhoneFindDisposition? {
        if requestID == nil || lastPhoneFindRequestID != requestID {
            phoneFindCount += 1
            lastPhoneFindAt = Date()
            lastPhoneFindRequestID = requestID
        }
        PhoneFindDiagnostics.record("find.received appState=\(UIApplication.shared.applicationState.rawValue) sound=\(phoneFindSoundEnabled)")
        message = "已收到设备的找手机请求"
        messageIsError = false
        phoneFindError = nil
        defer { onChange?() }
        guard phoneFindSoundEnabled else {
            message = "已收到找手机请求，响铃已关闭"
            return .disabled
        }
        #if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-featureTestControls") {
            isPhoneFindAlerting = phoneFindAuthorized
            return phoneFindAuthorized ? .accepted : .unauthorized
        }
        #endif
        if #available(iOS 26.0, *) {
            guard AlarmManager.shared.authorizationState == .authorized else {
                phoneFindAuthorized = false
                phoneFindError = "请先允许系统闹钟，再使用设备找手机"
                return .unauthorized
            }
            return await PhoneFindAlarmController.shared.ring() ? .accepted : nil
        }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        let authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        phoneFindAuthorized = authorized
        guard authorized else { return .unauthorized }
        let accepted = await PhoneFindNotifier.shared.trigger(soundEnabled: true)
        if accepted { isPhoneFindAlerting = true; return .accepted }
        return nil
    }

    private func clearPending() {
        timeout?.invalidate()
        timeout = nil
        pending = nil
        isSaving = false
    }

    private func fail(_ text: String) {
        clearPending()
        configuration = nil
        countdownRemaining = nil
        phase = .failed
        message = text
        messageIsError = true
        // A configuration timeout/error must not cancel the subscription or the
        // system-owned pending reconnect. Transport repairs its own link errors.
        onChange?()
    }
}

@available(iOS 26.0, *)
private struct PhoneFindAlarmMetadata: AlarmMetadata {}

/// One system-owned, one-shot alarm. A fixed schedule needs no countdown widget.
/// All mutations run on the main actor, including stop while schedule is in flight.
@available(iOS 26.0, *)
@MainActor
final class PhoneFindAlarmController {
    static let shared = PhoneFindAlarmController()
    private let id = UUID(uuidString: "EB8B538D-2769-4E8A-9324-7AC197CB5691")!
    private let manager = AlarmManager.shared
    var onChange: ((Bool, Bool, String?) -> Void)?
    private var observing: Task<Void, Never>?
    private var scheduling = false
    private var generation = 0
    private var stoppedDuringSchedule = false
    private var failure: String?

    private init() {
        observing = Task { @MainActor [weak self] in
            for await alarms in AlarmManager.shared.alarmUpdates {
                guard let self else { return }
                self.publish(alarms)
            }
        }
    }

    func refresh() {
        do { publish(try manager.alarms) }
        catch {
            PhoneFindDiagnostics.record("alarm.readError=\(error.localizedDescription)")
            failure = "无法读取系统闹钟状态，请重试"
            onChange?(false, false, failure)
        }
    }

    private func publish(_ alarms: [Alarm]) {
        let alarm = alarms.first { $0.id == id }
        let pending = (scheduling && !stoppedDuringSchedule) || alarm?.state == .scheduled
        let ringing = alarm?.state == .alerting
        PhoneFindDiagnostics.record("alarm.state=\(alarm.map { String(describing: $0.state) } ?? "none") pending=\(pending)")
        onChange?(pending, ringing, failure)
    }

    func ring() async -> Bool {
        guard manager.authorizationState == .authorized else {
            failure = "请先允许系统闹钟，再使用设备找手机"
            PhoneFindDiagnostics.record("alarm.rejected unauthorized")
            refresh()
            return false
        }
        // Repeated button presses must not create a queue of future alarms.
        guard !scheduling else { return false }
        do {
            if try manager.alarms.contains(where: { $0.id == id }) {
                refresh()
                return true
            }
        } catch {
            failure = "无法读取系统闹钟，请重试"
            refresh()
            return false
        }
        failure = nil
        scheduling = true
        stoppedDuringSchedule = false
        generation += 1
        let requestGeneration = generation
        onChange?(true, false, nil)

        // BLE grants a short execution window. Keep that window until the
        // system accepts the alarm; the system handles ringing afterwards.
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        func finishBackgroundTask() {
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "PhoneFindAlarm") { [weak self] in
            PhoneFindDiagnostics.record("alarm.taskExpired")
            self?.stop()
            finishBackgroundTask()
        }
        defer {
            scheduling = false
            finishBackgroundTask()
            refresh()
        }
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: "EasyFind · 手机在这里")
        } else {
            alert = AlarmPresentation.Alert(title: "EasyFind · 手机在这里",
                stopButton: AlarmButton(text: "停止响铃", textColor: .white, systemImageName: "stop.fill"))
        }
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert),
            metadata: PhoneFindAlarmMetadata(), tintColor: .blue)
        let configuration = AlarmManager.AlarmConfiguration<PhoneFindAlarmMetadata>.alarm(
            schedule: .fixed(Date().addingTimeInterval(2)), attributes: attributes, sound: .default)
        do {
            PhoneFindDiagnostics.record("alarm.schedule appState=\(UIApplication.shared.applicationState.rawValue)")
            let alarm = try await manager.schedule(id: id, configuration: configuration)
            if generation != requestGeneration {
                // Stop may happen while awaiting the system. Remove the late
                // result so an already-stopped request cannot ring afterwards.
                try? manager.cancel(id: id)
                PhoneFindDiagnostics.record("alarm.cancelledLateSchedule")
                return true // Explicit user stop consumes the request as well.
            } else {
                PhoneFindDiagnostics.record("alarm.accepted state=\(alarm.state)")
                publish([alarm])
                return true
            }
        } catch {
            failure = "系统闹钟未能启动：\(error.localizedDescription)"
            PhoneFindDiagnostics.record("alarm.scheduleError=\(error.localizedDescription)")
            return false
        }
    }

    func stop() {
        generation += 1
        stoppedDuringSchedule = true
        failure = nil
        do {
            if try manager.alarms.contains(where: { $0.id == id }) {
                try manager.cancel(id: id)
            }
            PhoneFindDiagnostics.record("alarm.cancelled")
        } catch {
            failure = "未能停止系统闹钟，请在锁屏上停止：\(error.localizedDescription)"
            PhoneFindDiagnostics.record("alarm.cancelError=\(error.localizedDescription)")
        }
        refresh()
    }
}

/// iOS 26 以前的通知提醒兼容入口。
///
/// 前台直接播放提示音并震动；后台由 CoreBluetooth 唤醒后安排本地通知。真正能否在锁屏
/// 播放声音仍受用户的通知权限和系统专注模式控制，不能由 BLE 协议强行绕过。
final class PhoneFindNotifier {
    static let shared = PhoneFindNotifier()
    private var player: AVAudioPlayer?
    private let notificationID = "easyfind.phone-find.active"
    private init() {
        NotificationCenter.default.addObserver(self, selector: #selector(stopSound), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    @MainActor
    func trigger(soundEnabled: Bool) async -> Bool {
        await withCheckedContinuation { continuation in
            trigger(soundEnabled: soundEnabled) { continuation.resume(returning: $0) }
        }
    }

    private func trigger(soundEnabled: Bool, completion: @escaping (Bool) -> Void) {
        stop()
        PhoneFindDiagnostics.record("notifier.trigger appState=\(UIApplication.shared.applicationState.rawValue)")
        if UIApplication.shared.applicationState == .active {
            if soundEnabled {
                // 前台使用可停止的音频播放器；不增加持续后台音频权限。
                do {
                    try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                    player = try AVAudioPlayer(data: Self.reminderSound())
                    player?.numberOfLoops = -1
                    let accepted = player?.play() == true
                    if accepted { AudioServicesPlaySystemSound(kSystemSoundID_Vibrate) }
                    completion(accepted)
                } catch { completion(false) }
            } else {
                completion(true)
            }
        } else {
            let content = UNMutableNotificationContent()
            content.title = "EasyFind"
            content.body = "自拍杆正在呼叫这部手机"
            content.sound = soundEnabled ? .default : nil
            let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: nil)
            // Finish asynchronous notification submission during the BLE wake.
            // This is a short task, not an attempt to keep the app running.
            var task: UIBackgroundTaskIdentifier = .invalid
            func finish() {
                if task != .invalid {
                    UIApplication.shared.endBackgroundTask(task)
                    task = .invalid
                }
            }
            task = UIApplication.shared.beginBackgroundTask(withName: "PhoneFindNotification") {
                PhoneFindDiagnostics.record("notification.taskExpired")
                finish()
            }
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                PhoneFindDiagnostics.record("notification.settings authorization=\(settings.authorizationStatus.rawValue) alert=\(settings.alertSetting.rawValue) sound=\(settings.soundSetting.rawValue) lockScreen=\(settings.lockScreenSetting.rawValue)")
            }
            UNUserNotificationCenter.current().add(request) { error in
                PhoneFindDiagnostics.record("notification.submitted error=\(error?.localizedDescription ?? "none")")
                DispatchQueue.main.async {
                    finish()
                    completion(error == nil)
                }
            }
        }
    }

    @objc func stopSound() {
        player?.stop()
        player = nil
    }

    func stop() {
        stopSound()
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    /// 一秒双提示音的 PCM WAV。无需外部音频资产，AVAudioPlayer 可立即停止。
    private static func reminderSound() -> Data {
        let sampleRate = 22050
        let byteCount = sampleRate * 2
        var data = Data()
        func word(_ value: UInt16) {
            data.append(UInt8(value & 0xff)); data.append(UInt8(value >> 8))
        }
        func dword(_ value: UInt32) {
            word(UInt16(value & 0xffff)); word(UInt16(value >> 16))
        }
        data.append(Data("RIFF".utf8)); dword(UInt32(36 + byteCount)); data.append(Data("WAVEfmt ".utf8))
        dword(16); word(1); word(1); dword(UInt32(sampleRate)); dword(UInt32(sampleRate * 2)); word(2); word(16)
        data.append(Data("data".utf8)); dword(UInt32(byteCount))
        for sample in 0..<sampleRate {
            let time = Double(sample) / Double(sampleRate)
            let part = time.truncatingRemainder(dividingBy: 0.3)
            let envelope = time < 0.6 && part < 0.2 ? min(1, min(part / 0.015, (0.2 - part) / 0.015)) : 0
            let value = Int16(sin(2 * .pi * 880 * time) * envelope * 10000)
            word(UInt16(bitPattern: value))
        }
        return data
    }
}

/// Small, bounded local trace containing lifecycle/events only, never device IDs.
/// Keep writable after the first unlock so locked-phone tests leave evidence.
enum PhoneFindDiagnostics {
    private static let queue = DispatchQueue(label: "easyfind.phone-find.diagnostics")
    static func record(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        queue.sync {
            guard let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let url = root.appendingPathComponent("phone-find-diagnostics.log")
            do {
                var data = (try? Data(contentsOf: url)) ?? Data()
                if data.count > 128 * 1024 { data = Data(data.suffix(64 * 1024)) }
                data.append(Data(line.utf8))
                try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            } catch { NSLog("PhoneFind diagnostics write failed: %@", error.localizedDescription) }
        }
    }
}

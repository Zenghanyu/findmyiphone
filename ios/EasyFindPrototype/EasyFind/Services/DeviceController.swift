import Foundation
import NearbyInteraction
import Observation

@MainActor @Observable
final class DeviceController {
  private(set) var name = "未连接设备"
  private(set) var status = "等待蓝牙连接"
  private(set) var ready = false
  private(set) var saving = false
  private(set) var delay: Int?
  private(set) var phoneEnabled = true
  private(set) var phoneAuthorized = false
  private(set) var alerting = false
  private(set) var error: String?
  private let remote: SelfieStickService
  private var pendingSave: (Int, CheckedContinuation<Void, Error>)?

  init(remote: SelfieStickService = .shared) {
    self.remote = remote
    remote.onChange = { [weak self] in self?.refresh() }
    refresh()
  }

  private func refresh() {
    name = remote.device?.name ?? "未连接遥控器"
    ready = remote.phase == .ready
    saving = remote.isSaving
    delay = remote.configuration.map { Int($0.delay) }
    phoneEnabled = remote.phoneFindSoundEnabled
    phoneAuthorized = remote.phoneFindAuthorized
    alerting = remote.isPhoneFindAlerting || remote.isPhoneFindScheduling
    error = remote.messageIsError ? remote.message : remote.phoneFindError
    status = ready ? "已连接" : remote.message ?? "请先在系统蓝牙中连接遥控器"
    if let (expected, continuation) = pendingSave, !saving {
      pendingSave = nil
      if ready, delay == expected, !remote.messageIsError {
        continuation.resume()
      } else {
        continuation.resume(throwing: DeviceError.unavailable(error ?? "设备未确认保存，请重新读取。"))
      }
    }
  }

  func retry() { remote.retry() }
  func authorizePhone() { remote.requestPhoneFindAuthorization() }
  func setPhoneEnabled(_ enabled: Bool) { remote.savePhoneFindSound(enabled: enabled) }
  func stopPhone() { remote.stopPhoneFind() }
  func saveDelay(_ value: Int) async throws {
    guard ready, !saving, pendingSave == nil, let config = remote.configuration,
      config.supportsOfflineShutter, (0...Int(config.maximumDelay)).contains(value),
      remote.countdownRemaining == nil
    else {
      throw DeviceError.unavailable("设备未就绪或正在拍照，请稍后再试。")
    }
    try await withCheckedThrowingContinuation { continuation in
      pendingSave = (value, continuation)
      remote.save(delay: value)
    }
  }
}

enum DeviceError: LocalizedError {
  case unavailable(String)
  var errorDescription: String? {
    if case .unavailable(let message) = self { return message }
    return nil
  }
}

@MainActor @Observable
final class RangingController {
  private(set) var tags: [ScannedTag] = []
  private(set) var distance: Float?
  private(set) var azimuth: Float?
  private(set) var status = "选择要查找的标签"
  private(set) var selected: String?
  private(set) var sounding = false
  var supportsUWB: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }
  private var scanner: TagScanner { .shared }
  private var service: TagRangingService { .shared }

  func start() {
    scanner.onDiscovered = { [weak self] tag in
      guard let self else { return }
      if let index = self.tags.firstIndex(where: { $0.address == tag.address }) {
        self.tags[index] = tag
      } else {
        self.tags.append(tag)
      }
    }
    scanner.onBluetoothStateChanged = { [weak self] state in
      if state == .poweredOn {
        self?.scanner.startDiscoveryScan()
      } else {
        self?.status = "蓝牙不可用，请检查系统设置"
      }
    }
    service.onMeasurement = { [weak self] address, measurement in
      guard let self, self.selected == address else { return }
      self.distance = measurement.distance
      self.azimuth = measurement.azimuth
      self.status = measurement.azimuth == nil ? "方向暂不可用，请缓慢移动手机" : "正在查找"
    }
    service.onSessionState = { [weak self] address, state in
      guard let self, self.selected == address else { return }
      if case .transportLost = state {
        self.distance = nil
        self.azimuth = nil
        self.status = "连接已断开，正在恢复"
      }
      if case .error = state {
        self.distance = nil
        self.azimuth = nil
        self.status = "测距失败，请重新选择设备"
      }
    }
    scanner.startDiscoveryScan()
  }

  func select(_ tag: ScannedTag) {
    stop()
    selected = tag.address
    status = "正在连接标签"
    guard supportsUWB else {
      status = "此手机不支持 UWB 精准测距"
      return
    }
    service.startRanging(address: tag.address, peripheral: tag.peripheral) { [weak self] session in
      if session == nil { self?.status = "无法连接标签，请重试" }
    }
  }
  func toggleSound() {
    guard let selected else { return }
    if sounding {
      service.stopSound(address: selected)
      sounding = false
    } else {
      service.playSound(address: selected) { [weak self] ok in
        self?.sounding = ok
        if !ok { self?.status = "发送发声指令失败" }
      }
    }
  }
  func stop() {
    if let selected {
      service.stopSound(address: selected)
      service.stopRanging(address: selected)
    }
    scanner.stopScan()
    distance = nil
    azimuth = nil
    sounding = false
    selected = nil
  }
}

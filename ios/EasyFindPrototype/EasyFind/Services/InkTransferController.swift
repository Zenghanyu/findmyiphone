import Observation
import SwiftUI

struct InkDevice: Identifiable {
  let id: String
  let name: String
  let rssi: String
}

@MainActor @Observable
final class InkTransferController {
  enum Phase { case idle, transferring, accepted, failed }
  private(set) var phase: Phase = .idle
  private(set) var progress = 0.0
  private(set) var message = "请先选择墨水屏"
  private(set) var devices: [InkDevice] = []
  private(set) var scanning = false
  private(set) var selectedID: String?
  private(set) var antiLost = false
  private let bridge = EFInkBridge()
  private var watchdog: Task<Void, Never>?
  private var generation = 0
  var busy: Bool { phase == .transferring }
  var canUpload: Bool { !busy && !scanning && (selectedID != nil || isTestMode) }
  var isTestMode: Bool {
    AppEnvironment.isUIReview && !ProcessInfo.processInfo.arguments.contains("-inkUseBluetooth")
  }

  init() {
    if let id = AppEnvironment.preferences.string(forKey: "easyfind.ink.mac") {
      _ = bind(id, antiLost: AppEnvironment.preferences.bool(forKey: "easyfind.ink.antiLost"))
    }
  }
  func scan() {
    guard !busy, !scanning else { return }
    scanning = true
    message = "正在扫描附近墨水屏"
    generation += 1
    let current = generation
    bridge.scan { [weak self] result, error in
      Task { @MainActor in
        guard let self, self.generation == current else { return }
        self.scanning = false
        self.devices = result.map {
          InkDevice(id: $0["id"] ?? "", name: $0["name"] ?? "墨水屏", rssi: $0["rssi"] ?? "")
        }
        self.message =
          error?.localizedDescription ?? (result.isEmpty ? "未发现墨水屏，请确认设备供电与蓝牙" : "请选择设备并确认屏幕型号")
      }
    }
  }
  @discardableResult func bind(_ id: String, antiLost: Bool) -> Bool {
    guard !busy, !scanning, bridge.bind(id, antiLost: antiLost) else { return false }
    selectedID = id
    self.antiLost = antiLost
    message = "已选择 HINK 240×240 六色屏"
    AppEnvironment.preferences.set(id, forKey: "easyfind.ink.mac")
    AppEnvironment.preferences.set(antiLost, forKey: "easyfind.ink.antiLost")
    return true
  }
  func upload(_ image: EFInkPreparedImage) {
    guard canUpload else { return }
    generation += 1
    let current = generation
    progress = 0
    phase = .transferring
    message = "正在向设备传输，请保持设备在附近"
    if isTestMode {
      #if targetEnvironment(simulator)
        watchdog = Task {
          try? await Task.sleep(for: .milliseconds(200))
          guard !Task.isCancelled else { return }
          self.phase = .accepted
          self.progress = 1
          self.message = "测试传输已完成"
        }
      #endif
      return
    }
    guard selectedID != nil else {
      phase = .failed
      message = "请先在设备设置中选择墨水屏"
      return
    }
    bridge.progress = { [weak self] value in
      Task { @MainActor in
        guard let self, self.generation == current else { return }
        self.progress = max(self.progress, value)
      }
    }
    bridge.status = { [weak self] _ in
      Task { @MainActor in
        guard let self, self.generation == current else { return }
        self.message = "正在向设备传输，请保持设备在附近"
      }
    }
    bridge.uploadPreparedImage(
      image,
      completion: { [weak self] accepted, error in
        Task { @MainActor in
          guard let self, self.generation == current else { return }
          self.watchdog?.cancel()
          self.phase = accepted ? .accepted : .failed
          self.progress = accepted ? 1 : self.progress
          self.message = accepted ? "设备已接收，请等待屏幕刷新" : error ?? "上传失败，请检查设备连接"
        }
      }
    )
    watchdog = Task {
      try? await Task.sleep(for: .seconds(180))
      guard !Task.isCancelled else { return }
      self.bridge.cancel()
      self.phase = .failed
      self.message = "传输超时，请检查设备后重试"
    }
  }
  func cancel() {
    generation += 1
    watchdog?.cancel()
    bridge.cancel()
    scanning = false
    if busy {
      phase = .idle
      progress = 0
      message = "传输已取消，设备可能已接收部分数据"
    }
  }
  func reset() {
    guard !busy else { return }
    phase = .idle
    progress = 0
    message = selectedID == nil ? "请先选择墨水屏" : "准备就绪"
  }
}

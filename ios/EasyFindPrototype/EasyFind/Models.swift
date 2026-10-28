import EasyFindCore
import SwiftUI

/// UI state and composition root. Persistence, scheduling, networking and BLE
/// remain behind their own services; views never write device protocol frames.
@MainActor @Observable
final class AppModel {
  let devices = DeviceController()
  let ranging = RangingController()
  let notifications = NotificationScheduler()
  let backend = BackendConnection()
  let generator = ArtworkGenerator()
  let ink = InkTransferController()
  let inkArtwork = InkArtworkController()
  private(set) var artworkRevision = UUID()
  var errorMessage: String?
  var selectedTab: AppTab = .device { didSet { save() } }
  var artwork: ArtworkKind = .mountain {
    didSet {
      invalidateInkArtwork()
      save()
    }
  }
  var photoDelaySeconds = 5 { didSet { save() } }
  var phoneLookupEnabled = true {
    didSet {
      devices.setPhoneEnabled(phoneLookupEnabled)
      save()
    }
  }
  var hourlyReminderEnabled = true {
    didSet {
      save()
      schedule()
    }
  }
  var hourlyStart = "09:00" {
    didSet {
      save()
      schedule()
    }
  }
  var hourlyEnd = "21:00" {
    didSet {
      save()
      schedule()
    }
  }
  var hourlyInterval = "每小时" {
    didSet {
      save()
      schedule()
    }
  }
  var reminders: [ReminderItem] = ReminderItem.defaults {
    didSet {
      save()
      schedule()
    }
  }
  var selectedPhotoData: Data? {
    didSet {
      invalidateInkArtwork()
      guard loaded, !storageFailed else { return }
      do { try photos.save(selectedPhotoData) } catch { errorMessage = error.localizedDescription }
    }
  }
  private let store: JSONFileStore<Snapshot>
  private let photos: PhotoRepository
  private var loaded = false
  private var storageFailed = false
  private var updatingRule = false

  init() {
    let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent(AppEnvironment.storageName, isDirectory: true)
    store = JSONFileStore(url: root.appendingPathComponent("settings-v2.json"))
    photos = PhotoRepository(url: root.appendingPathComponent("selected-photo.data"))
    do {
      var saved = try store.load()
      if saved == nil, let legacy = UserDefaults.standard.data(forKey: "easyfind.native.v1") {
        saved = try JSONDecoder().decode(Snapshot.self, from: legacy)
        if let saved { try store.save(saved) }
      }
      if let saved {
        selectedTab = saved.selectedTab
        artwork = saved.artwork
        photoDelaySeconds = min(30, max(0, saved.photoDelaySeconds))
        phoneLookupEnabled = saved.phoneLookupEnabled
        hourlyReminderEnabled = saved.hourlyReminderEnabled
        hourlyStart = saved.hourlyStart
        hourlyEnd = saved.hourlyEnd
        hourlyInterval = saved.hourlyInterval
        reminders = saved.reminders.map { item in
          var migrated = item
          if item.repeatRule == "仅一次", item.onceAt == nil, let time = try? LocalTime(item.time) {
            migrated.onceAt = Calendar.current.nextDate(
              after: Date(), matching: DateComponents(hour: time.hour, minute: time.minute),
              matchingPolicy: .nextTime)
          }
          return migrated
        }
      }
      selectedPhotoData = try photos.load()
    } catch {
      storageFailed = true
      errorMessage = "本地数据读取失败，原文件已保留：" + error.localizedDescription
    }
    loaded = true
    save()
    devices.setPhoneEnabled(phoneLookupEnabled)
    schedule()
  }
  private func save() {
    guard loaded, !storageFailed, !updatingRule else { return }
    do {
      try store.save(
        Snapshot(
          selectedTab: selectedTab, artwork: artwork,
          photoDelaySeconds: photoDelaySeconds, phoneLookupEnabled: phoneLookupEnabled,
          hourlyReminderEnabled: hourlyReminderEnabled, hourlyStart: hourlyStart,
          hourlyEnd: hourlyEnd, hourlyInterval: hourlyInterval, reminders: reminders))
    } catch { errorMessage = "保存失败：" + error.localizedDescription }
  }
  func schedule() {
    guard loaded, !storageFailed, !updatingRule else { return }
    do {
      let items = try reminders.map { item -> Reminder in
        let time = try LocalTime(item.time)
        let rule: RepeatRule =
          item.repeatRule == "工作日" ? .weekdays : item.repeatRule == "仅一次" ? .once : .daily
        return Reminder(
          id: item.id, title: item.title, time: time, rule: rule, enabled: item.isEnabled,
          onceAt: item.onceAt)
      }
      let hourly = try HourlyRule(
        enabled: hourlyReminderEnabled, start: LocalTime(hourlyStart),
        end: LocalTime(hourlyEnd), intervalHours: hourlyInterval == "每两小时" ? 2 : 1)
      notifications.reconcile(reminders: items, hourly: hourly)
    } catch { errorMessage = error.localizedDescription }
  }
  func authorizeReminders() async {
    await notifications.requestAuthorization()
    schedule()
  }
  func saveHourly(start: String, end: String, interval: String) {
    updatingRule = true
    hourlyStart = start
    hourlyEnd = end
    hourlyInterval = interval
    updatingRule = false
    save()
    schedule()
  }
  func importPhoto(_ data: Data) async {
    do { selectedPhotoData = try await PhotoRepository.normalized(data) } catch {
      errorMessage = error.localizedDescription
    }
  }
  private func invalidateInkArtwork() {
    artworkRevision = UUID()
    inkArtwork.invalidate()
  }
  func prepareInkArtwork() {
    let image: UIImage?
    if let data = selectedPhotoData {
      image = UIImage(data: data)
    } else {
      let renderer = ImageRenderer(
        content: ArtworkView(kind: artwork).frame(width: 240, height: 240))
      renderer.scale = 1
      image = renderer.uiImage
    }
    guard let image else {
      errorMessage = "无法准备画面，请重新选择图片。"
      return
    }
    inkArtwork.prepare(
      image, key: .init(revision: artworkRevision, antiLost: ink.antiLost))
  }
  func deleteReminder(_ reminder: ReminderItem) { reminders.removeAll { $0.id == reminder.id } }
}

private struct Snapshot: Codable {
  let selectedTab: AppTab
  let artwork: ArtworkKind
  let photoDelaySeconds: Int
  let phoneLookupEnabled: Bool
  let hourlyReminderEnabled: Bool
  let hourlyStart: String
  let hourlyEnd: String
  let hourlyInterval: String
  let reminders: [ReminderItem]
}

enum AppTab: String, Codable {
  case device, ink, reminders
}

enum ArtworkKind: String, Codable, CaseIterable, Identifiable {
  case mountain, city, bloom

  var id: String { rawValue }
  var title: String {
    switch self {
    case .mountain: "山野慢生活"
    case .city: "城市日落"
    case .bloom: "花开时节"
    }
  }
  var shortTitle: String {
    switch self {
    case .mountain: "慢慢来"
    case .city: "城市日落"
    case .bloom: "花开时节"
    }
  }
  var heading: String {
    switch self {
    case .mountain: "SLOW DAYS"
    case .city: "CITY LIGHTS"
    case .bloom: "IN BLOOM"
    }
  }
}

struct ReminderItem: Identifiable, Codable, Hashable {
  let id: UUID
  var time: String
  var title: String
  var repeatRule: String
  var isEnabled: Bool
  var onceAt: Date? = nil

  static let defaults = [
    ReminderItem(id: UUID(), time: "10:00", title: "记得喝水", repeatRule: "每天", isEnabled: true),
    ReminderItem(id: UUID(), time: "15:30", title: "项目讨论", repeatRule: "工作日", isEnabled: true),
  ]
}

enum DeviceRoute: Hashable {
  case camera, find, phone, settings
}

enum InkRoute: Hashable {
  case templates, capture, ai, upload
}

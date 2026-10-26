import SwiftUI

@Observable
final class AppModel {
    var selectedTab: AppTab = .device { didSet { save() } }
    var artwork: ArtworkKind = .mountain { didSet { save() } }
    var photoDelaySeconds = 5 { didSet { save() } }
    var phoneLookupEnabled = true { didSet { save() } }
    var hourlyReminderEnabled = true { didSet { save() } }
    var hourlyStart = "09:00" { didSet { save() } }
    var hourlyEnd = "21:00" { didSet { save() } }
    var hourlyInterval = "每小时" { didSet { save() } }
    var reminders: [ReminderItem] = ReminderItem.defaults { didSet { save() } }

    // Photos remain session-only, matching the original prototype's privacy boundary.
    var selectedPhotoData: Data?

    private let storageKey = "easyfind.native.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        selectedTab = saved.selectedTab
        artwork = saved.artwork
        photoDelaySeconds = min(30, max(0, saved.photoDelaySeconds))
        phoneLookupEnabled = saved.phoneLookupEnabled
        hourlyReminderEnabled = saved.hourlyReminderEnabled
        hourlyStart = saved.hourlyStart
        hourlyEnd = saved.hourlyEnd
        hourlyInterval = saved.hourlyInterval
        reminders = saved.reminders
    }

    private func save() {
        let snapshot = Snapshot(
            selectedTab: selectedTab,
            artwork: artwork,
            photoDelaySeconds: photoDelaySeconds,
            phoneLookupEnabled: phoneLookupEnabled,
            hourlyReminderEnabled: hourlyReminderEnabled,
            hourlyStart: hourlyStart,
            hourlyEnd: hourlyEnd,
            hourlyInterval: hourlyInterval,
            reminders: reminders
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    func deleteReminder(_ reminder: ReminderItem) {
        reminders.removeAll { $0.id == reminder.id }
    }
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

    static let defaults = [
        ReminderItem(id: UUID(), time: "10:00", title: "记得喝水", repeatRule: "每天", isEnabled: true),
        ReminderItem(id: UUID(), time: "15:30", title: "项目讨论", repeatRule: "工作日", isEnabled: true)
    ]
}

enum DeviceRoute: Hashable {
    case camera, find, phone, settings
}

enum InkRoute: Hashable {
    case templates, capture, ai, upload
}

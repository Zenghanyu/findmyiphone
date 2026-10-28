import Foundation

public enum ValidationError: Error, Equatable, LocalizedError {
  case invalidTime, invalidRange, emptyTitle, invalidDate, tooManyNotifications
  public var errorDescription: String? {
    switch self {
    case .invalidTime: return "时间格式应为 HH:mm。"
    case .invalidRange: return "结束时间需晚于开始时间。"
    case .emptyTitle: return "请填写提醒事项。"
    case .invalidDate: return "单次提醒时间需晚于当前时间。"
    case .tooManyNotifications: return "提醒数量超过系统容量，请减少事项或报时频率。"
    }
  }
}

public struct LocalTime: Codable, Equatable, Sendable {
  public let hour: Int
  public let minute: Int
  public init(_ value: String) throws {
    let parts = value.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 2, parts.allSatisfy({ $0.count == 2 }),
      let hour = Int(parts[0]), let minute = Int(parts[1]),
      (0...23).contains(hour), (0...59).contains(minute)
    else { throw ValidationError.invalidTime }
    self.hour = hour
    self.minute = minute
  }
  public var minutes: Int { hour * 60 + minute }
}

public enum RepeatRule: String, Codable, Sendable { case daily, weekdays, once }

public struct Reminder: Sendable {
  public let id: UUID
  public let title: String
  public let time: LocalTime
  public let rule: RepeatRule
  public let enabled: Bool
  public let onceAt: Date?
  public init(
    id: UUID, title: String, time: LocalTime, rule: RepeatRule, enabled: Bool, onceAt: Date? = nil
  ) {
    self.id = id
    self.title = title
    self.time = time
    self.rule = rule
    self.enabled = enabled
    self.onceAt = onceAt
  }
}

public struct HourlyRule: Sendable {
  public let enabled: Bool
  public let start: LocalTime
  public let end: LocalTime
  public let intervalHours: Int
  public init(enabled: Bool, start: LocalTime, end: LocalTime, intervalHours: Int) {
    self.enabled = enabled
    self.start = start
    self.end = end
    self.intervalHours = intervalHours
  }
}

public struct NotificationPlan: Equatable, Sendable {
  public let id: String
  public let title: String
  public let components: DateComponents
  public let repeats: Bool
}

/// Floating local time: recurring reminders follow the phone's current time zone.
/// Single reminders use an absolute date and never silently move to tomorrow.
public enum ReminderPlanner {
  public static let prefix = "easyfind.reminder."
  public static func plan(
    _ reminders: [Reminder], hourly: HourlyRule,
    now: Date = Date(), timeZone: TimeZone = .current,
    capacity: Int = 64
  ) throws -> [NotificationPlan] {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    var plans: [NotificationPlan] = []
    for reminder in reminders where reminder.enabled {
      let title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !title.isEmpty else { throw ValidationError.emptyTitle }
      let base = prefix + reminder.id.uuidString
      switch reminder.rule {
      case .daily, .weekdays:
        let days: [Int?] = reminder.rule == .daily ? [nil] : (2...6).map { Optional($0) }
        for day in days {
          var parts = DateComponents()
          parts.hour = reminder.time.hour
          parts.minute = reminder.time.minute
          parts.weekday = day
          plans.append(
            NotificationPlan(
              id: base + ".\(day ?? 0)", title: title, components: parts, repeats: true))
        }
      case .once:
        guard let date = reminder.onceAt else { throw ValidationError.invalidDate }
        // Already delivered one-off reminders are retained in storage, not rescheduled.
        guard date > now else { continue }
        var parts = calendar.dateComponents(
          [.year, .month, .day, .hour, .minute, .second], from: date)
        parts.timeZone = timeZone
        plans.append(NotificationPlan(id: base, title: title, components: parts, repeats: false))
      }
    }
    if hourly.enabled {
      guard hourly.end.minutes > hourly.start.minutes, (1...24).contains(hourly.intervalHours)
      else {
        throw ValidationError.invalidRange
      }
      for minute in stride(
        from: hourly.start.minutes, through: hourly.end.minutes, by: hourly.intervalHours * 60)
      {
        var parts = DateComponents()
        parts.hour = minute / 60
        parts.minute = minute % 60
        plans.append(
          NotificationPlan(
            id: prefix + "hourly.\(minute)",
            title: String(format: "现在是 %02d:%02d", minute / 60, minute % 60), components: parts,
            repeats: true))
      }
    }
    guard plans.count <= capacity else { throw ValidationError.tooManyNotifications }
    return plans
  }
}

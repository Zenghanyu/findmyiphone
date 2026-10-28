import EasyFindCore
import Foundation
import Observation
import UserNotifications

@MainActor @Observable
final class NotificationScheduler {
  private(set) var authorized = false
  private(set) var error: String?
  private let center = UNUserNotificationCenter.current()
  private var tail: Task<Void, Never>?

  func requestAuthorization() async {
    do {
      authorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    } catch { self.error = error.localizedDescription }
  }

  /// Serializes complete reconciliation operations, including across suspension points.
  func reconcile(reminders: [Reminder], hourly: HourlyRule) {
    let previous = tail
    tail = Task { [weak self] in
      await previous?.value
      guard let self else { return }
      do {
        let settings = await self.center.notificationSettings()
        self.authorized = [.authorized, .provisional, .ephemeral].contains(
          settings.authorizationStatus)
        let existing = await self.center.pendingNotificationRequests()
        let unrelated = existing.filter { !$0.identifier.hasPrefix(ReminderPlanner.prefix) }.count
        let plans = try ReminderPlanner.plan(
          reminders, hourly: hourly, capacity: max(0, 64 - unrelated))
        let owned = existing.filter { $0.identifier.hasPrefix(ReminderPlanner.prefix) }
        if !self.authorized, !plans.isEmpty {
          self.error = "请允许系统通知，提醒规则已保存，授权后会自动安排。"
          return
        }
        let requests = plans.map { plan -> UNNotificationRequest in
          let content = UNMutableNotificationContent()
          content.title = plan.title
          content.sound = .default
          return UNNotificationRequest(
            identifier: plan.id, content: content,
            trigger: UNCalendarNotificationTrigger(
              dateMatching: plan.components, repeats: plan.repeats))
        }
        // Remove only this feature's requests. Roll back if the system rejects an addition.
        self.center.removePendingNotificationRequests(withIdentifiers: owned.map(\.identifier))
        do {
          for request in requests { try await self.center.add(request) }
        } catch {
          self.center.removePendingNotificationRequests(withIdentifiers: requests.map(\.identifier))
          for request in owned { try? await self.center.add(request) }
          throw error
        }
        self.error = nil
      } catch { self.error = error.localizedDescription }
    }
  }
}

import SwiftUI
import UserNotifications

@main
struct EasyFindApp: App {
  @UIApplicationDelegateAdaptor(BackendAppDelegate.self) private var appDelegate
  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}

final class BackendAppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
  ) -> Bool {
    // CoreBluetooth restoration may launch the process without creating a scene.
    _ = SelfieStickService.shared
    UNUserNotificationCenter.current().delegate = self
    return true
  }
}

extension BackendAppDelegate: UNUserNotificationCenterDelegate {
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    completionHandler([.banner, .sound])
  }
}

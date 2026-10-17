import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    private var lifecycleObservers: [NSObjectProtocol] = []

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        if #available(iOS 26.0, *) {
            // iOS 26 deprecates the launch-options restoration hint. The
            // restoration callback itself records whether state was restored.
            PhoneFindDiagnostics.record("launch state=\(application.applicationState.rawValue) bleRestoreBootstrap=unconditional")
        } else {
            let restoringManagers = launchOptions?[.bluetoothCentrals] as? [String] ?? []
            PhoneFindDiagnostics.record("launch state=\(application.applicationState.rawValue) bleRestoreManagers=\(restoringManagers.count)")
        }
        // These observers do not create or retain a scene. Background BLE
        // restoration still starts the service when no UI is ever requested.
        for (name, event) in [
            (UIScene.didEnterBackgroundNotification, "scene.background"),
            (UIScene.willEnterForegroundNotification, "scene.foreground")
        ] {
            lifecycleObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                PhoneFindDiagnostics.record(event)
            })
        }
        // CoreBluetooth can relaunch us without creating a scene. Recreate the
        // restoration manager here, and keep it alive independently of the UI.
        _ = SelfieStickService.shared
        return true
    }

    deinit {
        for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}

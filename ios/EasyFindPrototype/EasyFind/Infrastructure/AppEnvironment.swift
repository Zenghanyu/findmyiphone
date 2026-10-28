import Foundation

/// UI automation uses separate files, preferences and Keychain entries.
/// Device builds always use the normal application namespace.
enum AppEnvironment {
  static let isUIReview: Bool = {
    #if targetEnvironment(simulator)
      return ProcessInfo.processInfo.arguments.contains("-uiMock")
    #else
      return false
    #endif
  }()
  static let storageName = isUIReview ? "EasyFind-UIReview" : "EasyFind"
  static let preferences: UserDefaults =
    isUIReview ? UserDefaults(suiteName: "com.easyfind.companion.uireview")! : .standard
  static let tokenAccount =
    "easyfind.api.client-token" + (isUIReview ? ".uireview" : "")
}

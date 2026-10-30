import EasyFindCore
import Foundation
import Observation
import Security

@MainActor @Observable
final class BackendConnection {
  var address: String
  private let defaults: UserDefaults
  private let account = AppEnvironment.tokenAccount
  init(defaults: UserDefaults = AppEnvironment.preferences) {
    self.defaults = defaults
    address = defaults.string(forKey: "easyfind.api.url") ?? "http://127.0.0.1:8000"
  }
  func client() throws -> APIClient {
    guard let url = URL(string: address), let token = readToken(), !token.isEmpty else {
      throw ServiceError.notConfigured
    }
    return try APIClient(baseURL: url, token: token)
  }
  func save(address: String, token: String) throws {
    let value = address.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let url = URL(string: value) else { throw ServiceError.notConfigured }
    let credential = token.isEmpty ? readToken() ?? "" : token
    _ = try APIClient(baseURL: url, token: credential)
    let key: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Bundle.main.bundleIdentifier ?? "EasyFind",
      kSecAttrAccount as String: account,
    ]
    let bytes = Data(credential.utf8)
    let result = SecItemUpdate(
      key as CFDictionary, [kSecValueData as String: bytes] as CFDictionary)
    if result == errSecItemNotFound {
      var entry = key
      entry[kSecValueData as String] = bytes
      entry[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      guard SecItemAdd(entry as CFDictionary, nil) == errSecSuccess else {
        throw DeviceError.unavailable("访问令牌保存失败。")
      }
    } else if result != errSecSuccess {
      throw DeviceError.unavailable("访问令牌保存失败。")
    }
    self.address = value
    defaults.set(value, forKey: "easyfind.api.url")
  }
  private func readToken() -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: Bundle.main.bundleIdentifier ?? "EasyFind",
      kSecAttrAccount as String: account,
      kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
      let data = result as? Data
    else { return nil }
    return String(data: data, encoding: .utf8)
  }
}

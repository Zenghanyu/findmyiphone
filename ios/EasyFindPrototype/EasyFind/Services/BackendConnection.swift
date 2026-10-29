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

@MainActor @Observable
final class ArtworkGenerator {
  private(set) var running = false
  private(set) var error: String?
  private(set) var imageData: Data?
  private var task: Task<Void, Never>?
  private var job: (any ArtworkAPI, String)?
  private var pendingRequest: (String, UUID)?
  func generate(prompt: String, api: any ArtworkAPI) {
    guard !running else { return }
    error = nil
    imageData = nil
    running = true
    task = Task {
      defer { self.running = false }
      do {
        let key = pendingRequest?.0 == prompt ? pendingRequest!.1 : UUID()
        pendingRequest = (prompt, key)
        let created = try await api.createArtwork(prompt: prompt, idempotencyKey: key)
        pendingRequest = nil
        self.job = (api, created.id)
        for _ in 0..<180 {
          try Task.checkCancellation()
          let current = try await api.artworkJob(id: created.id)
          switch current.status {
          case .succeeded:
            self.imageData = try await api.artworkImage(id: created.id)
            self.job = nil
            return
          case .failed: throw ServiceError.server(502, current.error ?? "生成失败，请重试。")
          case .cancelled: throw ServiceError.cancelled
          case .pending, .running: try await Task.sleep(for: .seconds(1))
          }
        }
        throw ServiceError.timeout
      } catch is CancellationError {
        if let (api, id) = self.job { try? await api.cancelArtwork(id: id) }
        self.job = nil
      } catch {
        if let (api, id) = self.job { try? await api.cancelArtwork(id: id) }
        self.job = nil
        self.error = error.localizedDescription
      }
    }
  }
  func cancel() {
    task?.cancel()
    if let (api, id) = job { Task { try? await api.cancelArtwork(id: id) } }
    job = nil
  }
}

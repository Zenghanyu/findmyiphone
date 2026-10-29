import Foundation

public enum ServiceError: Error, LocalizedError, Equatable {
  case notConfigured, invalidResponse
  case server(Int, String)
  case cancelled, timeout
  public var errorDescription: String? {
    switch self {
    case .notConfigured: return "请先在服务设置中填写后端地址与访问令牌。"
    case .invalidResponse: return "服务返回的数据格式不正确。"
    case .server(_, let message): return message
    case .cancelled: return "任务已取消。"
    case .timeout: return "生成超时，请稍后查看或重试。"
    }
  }
}

public struct ArtworkJob: Codable, Equatable, Sendable {
  public enum Status: String, Codable, Sendable {
    case pending, running, succeeded, failed, cancelled
  }
  public let id: String
  public let status: Status
  public let error: String?
}

public struct FeedbackReceipt: Codable, Sendable { public let id: String }

public protocol ArtworkAPI: Sendable {
  func createArtwork(prompt: String, idempotencyKey: UUID) async throws -> ArtworkJob
  func artworkJob(id: String) async throws -> ArtworkJob
  func artworkImage(id: String) async throws -> Data
  func cancelArtwork(id: String) async throws
  func submitFeedback(category: String, details: String, contact: String, attachments: [Data])
    async throws
    -> FeedbackReceipt
}

extension ArtworkAPI {
  public func submitFeedback(category: String, details: String, contact: String) async throws
    -> FeedbackReceipt
  {
    try await submitFeedback(
      category: category, details: details, contact: contact, attachments: [])
  }
}

/// Networking and DTOs have no dependency on SwiftUI, device SDKs or app state.
public struct APIClient: ArtworkAPI, Sendable {
  private let baseURL: URL
  private let token: String
  private let session: URLSession

  public init(baseURL: URL, token: String, session: URLSession = .shared) throws {
    guard ["http", "https"].contains(baseURL.scheme?.lowercased() ?? ""),
      baseURL.host != nil, baseURL.user == nil, baseURL.password == nil,
      baseURL.query == nil, baseURL.fragment == nil, !token.isEmpty
    else { throw ServiceError.notConfigured }
    let localHosts = ["localhost", "127.0.0.1", "::1"]
    guard baseURL.scheme == "https" || localHosts.contains(baseURL.host ?? "") else {
      throw ServiceError.notConfigured
    }
    self.baseURL = baseURL
    self.token = token
    self.session = session
  }

  public func createArtwork(prompt: String, idempotencyKey: UUID) async throws -> ArtworkJob {
    let body = try JSONSerialization.data(withJSONObject: [
      "prompt": prompt, "width": 1024, "height": 1024,
    ])
    return try decode(
      await send("v1/artwork-jobs", method: "POST", body: body, key: idempotencyKey.uuidString))
  }
  public func artworkJob(id: String) async throws -> ArtworkJob {
    try decode(await send("v1/artwork-jobs/\(try safeID(id))"))
  }
  public func artworkImage(id: String) async throws -> Data {
    try await send("v1/artwork-jobs/\(try safeID(id))/image")
  }
  public func cancelArtwork(id: String) async throws {
    _ = try await send("v1/artwork-jobs/\(try safeID(id))", method: "DELETE")
  }
  public func submitFeedback(
    category: String, details: String, contact: String, attachments: [Data]
  ) async throws
    -> FeedbackReceipt
  {
    guard attachments.count <= 10, attachments.allSatisfy({ !$0.isEmpty && $0.count <= 512 * 1024 })
    else {
      throw ServiceError.invalidResponse
    }
    let body = try JSONSerialization.data(withJSONObject: [
      "category": category, "details": details, "contact": contact,
      "attachments": attachments.map { ["image_base64": $0.base64EncodedString()] },
    ])
    return try decode(await send("v1/feedback", method: "POST", body: body))
  }
  private func safeID(_ id: String) throws -> String {
    guard UUID(uuidString: id) != nil else { throw ServiceError.invalidResponse }
    return id
  }
  private func decode<T: Decodable>(_ data: Data) throws -> T {
    guard let value = try? JSONDecoder().decode(T.self, from: data) else {
      throw ServiceError.invalidResponse
    }
    return value
  }
  private func send(_ path: String, method: String = "GET", body: Data? = nil, key: String? = nil)
    async throws -> Data
  {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = method
    request.httpBody = body
    request.timeoutInterval = 30
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let key { request.setValue(key, forHTTPHeaderField: "Idempotency-Key") }
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else { throw ServiceError.invalidResponse }
    guard (200...299).contains(http.statusCode) else {
      let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      throw ServiceError.server(
        http.statusCode, object?["detail"] as? String ?? "请求失败（\(http.statusCode)），请稍后重试。")
    }
    guard data.count <= 20 * 1024 * 1024 else { throw ServiceError.invalidResponse }
    return data
  }
}

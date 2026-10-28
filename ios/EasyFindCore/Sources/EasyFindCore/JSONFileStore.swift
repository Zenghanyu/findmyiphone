import Foundation

/// Callers serialize access. Writes are atomic; decoding failures are surfaced
/// so a corrupt file is never silently overwritten with default state.
public struct JSONFileStore<Value: Codable> {
  public let url: URL
  public init(url: URL) { self.url = url }
  public func load() throws -> Value? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
  }
  public func save(_ value: Value) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONEncoder().encode(value).write(to: url, options: .atomic)
  }
}

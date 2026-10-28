import ImageIO
import UIKit

struct PhotoRepository {
  let url: URL
  func load() throws -> Data? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try Data(contentsOf: url)
  }
  func save(_ data: Data?) throws {
    guard let data else {
      if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
      }
      return
    }
    guard data.count <= 20 * 1024 * 1024, UIImage(data: data) != nil else {
      throw DeviceError.unavailable("无法读取图片，或图片超过 20 MB。")
    }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: url, options: .atomic)
  }
  static func normalized(_ data: Data) async throws -> Data {
    try await Task.detached(priority: .userInitiated) {
      guard data.count <= 20 * 1024 * 1024,
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        let image = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048,
          ] as CFDictionary),
        let result = UIImage(cgImage: image).jpegData(compressionQuality: 0.95)
      else {
        throw DeviceError.unavailable("无法读取图片，或图片超过 20 MB。")
      }
      return result
    }.value
  }
}

import EasyFindCore
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
  static func normalized(_ image: UIImage) async throws -> UIImage {
    try await Task.detached(priority: .userInitiated) {
      guard image.size.width > 0, image.size.height > 0 else { throw ServiceError.invalidResponse }
      let ratio = min(1, 2048 / max(image.size.width, image.size.height))
      let size = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
      let format = UIGraphicsImageRendererFormat()
      format.scale = 1
      format.opaque = true
      return UIGraphicsImageRenderer(size: size, format: format).image { context in
        UIColor.white.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        image.draw(in: CGRect(origin: .zero, size: size))
      }
    }.value
  }
  static func cropped(_ image: UIImage, canvasSide: CGFloat, zoom: CGFloat, offset: CGSize)
    async throws -> Data
  {
    try await Task.detached(priority: .userInitiated) {
      guard let source = image.cgImage, image.imageOrientation == .up else {
        throw ServiceError.invalidResponse
      }
      let rect = try PhotoCropGeometry.sourceRect(
        imageSize: CGSize(width: source.width, height: source.height),
        canvasSide: canvasSide, zoom: zoom, offset: offset)
      guard let cropped = source.cropping(to: rect.integral),
        let data = UIImage(cgImage: cropped).jpegData(compressionQuality: 0.95)
      else { throw ServiceError.invalidResponse }
      return data
    }.value
  }
  static func feedbackAttachment(_ data: Data) async throws -> Data {
    try await Task.detached(priority: .userInitiated) {
      guard data.count <= 20 * 1024 * 1024,
        let source = CGImageSourceCreateWithData(data as CFData, nil),
        let cg = CGImageSourceCreateThumbnailAtIndex(
          source, 0,
          [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1280,
          ] as CFDictionary)
      else { throw ServiceError.invalidResponse }
      let image = UIImage(cgImage: cg)
      for quality in [0.8, 0.6, 0.4, 0.2] {
        if let jpeg = image.jpegData(compressionQuality: quality), jpeg.count <= 512 * 1024 {
          return jpeg
        }
      }
      throw DeviceError.unavailable("反馈图片过大，请选择其他图片。")
    }.value
  }
}

import CoreGraphics
import Foundation

/// Maps the visible square to source pixels, preserving detail for DPID later.
public enum PhotoCropGeometry {
  public static func sourceRect(
    imageSize: CGSize, canvasSide: CGFloat, zoom: CGFloat, offset: CGSize
  ) throws -> CGRect {
    let values = [imageSize.width, imageSize.height, canvasSide, zoom, offset.width, offset.height]
    guard values.allSatisfy(\.isFinite), imageSize.width > 0, imageSize.height > 0,
      canvasSide > 0, (1...4).contains(zoom)
    else { throw ServiceError.invalidResponse }
    let scale = max(canvasSide / imageSize.width, canvasSide / imageSize.height) * zoom
    let side = canvasSide / scale
    let x = (imageSize.width - side) / 2 - offset.width / scale
    let y = (imageSize.height - side) / 2 - offset.height / scale
    return CGRect(
      x: min(max(0, x), imageSize.width - side),
      y: min(max(0, y), imageSize.height - side), width: side, height: side)
  }
}

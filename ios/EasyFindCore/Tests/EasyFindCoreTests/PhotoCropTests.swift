import CoreGraphics
import XCTest

@testable import EasyFindCore

final class PhotoCropTests: XCTestCase {
  func testLandscapePanAndZoomKeepSourceResolution() throws {
    let size = CGSize(width: 640, height: 320)
    XCTAssertEqual(
      try PhotoCropGeometry.sourceRect(imageSize: size, canvasSide: 320, zoom: 1, offset: .zero),
      CGRect(x: 160, y: 0, width: 320, height: 320))
    XCTAssertEqual(
      try PhotoCropGeometry.sourceRect(
        imageSize: size, canvasSide: 320, zoom: 1,
        offset: CGSize(width: 160, height: 0)),
      CGRect(x: 0, y: 0, width: 320, height: 320))
    XCTAssertEqual(
      try PhotoCropGeometry.sourceRect(imageSize: size, canvasSide: 320, zoom: 2, offset: .zero),
      CGRect(x: 240, y: 80, width: 160, height: 160))
  }

  func testPortraitPanIsClampedInsideImage() throws {
    XCTAssertEqual(
      try PhotoCropGeometry.sourceRect(
        imageSize: CGSize(width: 320, height: 640),
        canvasSide: 320, zoom: 1,
        offset: CGSize(width: 999, height: -999)),
      CGRect(x: 0, y: 320, width: 320, height: 320))
  }

  func testRejectsInvalidGeometry() {
    for (size, canvas, zoom, offset) in [
      (CGSize.zero, CGFloat(320), CGFloat(1), CGSize.zero),
      (CGSize(width: 320, height: 640), 0, 1, .zero),
      (CGSize(width: 320, height: 640), 320, 0, .zero),
      (CGSize(width: 320, height: 640), 320, 5, .zero),
      (CGSize(width: 320, height: 640), 320, 1, CGSize(width: CGFloat.nan, height: 0)),
    ] {
      XCTAssertThrowsError(
        try PhotoCropGeometry.sourceRect(
          imageSize: size, canvasSide: canvas, zoom: zoom, offset: offset))
    }
  }
}

import PhotonCore
import XCTest

final class IconArtworkTests: XCTestCase {
  func testFinderSizedArtworkIsLeftAlone() {
    XCTAssertFalse(IconArtwork.needsCrop(contentFraction: 0.84))
    XCTAssertFalse(IconArtwork.needsCrop(contentFraction: 1))
    XCTAssertFalse(IconArtwork.needsCrop(contentFraction: IconArtwork.fullFraction))
  }

  func testASpeckInsideAClearSquareIsCropped() {
    XCTAssertTrue(IconArtwork.needsCrop(contentFraction: 0.2))
    XCTAssertTrue(IconArtwork.needsCrop(contentFraction: 0.45))
  }

  func testAnEmptyBitmapIsNotCropped() {
    XCTAssertFalse(IconArtwork.needsCrop(contentFraction: 0))
  }
}

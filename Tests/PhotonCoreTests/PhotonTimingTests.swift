import PhotonCore
import XCTest

final class PhotonTimingTests: XCTestCase {
  func testDebugFlagDefaultsOff() {
    XCTAssertNotEqual(ProcessInfo.processInfo.environment["PHOTON_DEBUG"], "1")
    XCTAssertFalse(PhotonTiming.isEnabled)
    XCTAssertNil(PhotonTiming.start())
  }

  func testMillisecondConversionIsNonNegative() {
    let start = ContinuousClock.now
    let ms = PhotonTiming.milliseconds(from: start, to: start)
    XCTAssertEqual(ms, 0, accuracy: 0.5)
  }
}

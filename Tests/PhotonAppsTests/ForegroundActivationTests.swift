import AppKit
import PhotonApps
import XCTest

final class ForegroundActivationTests: XCTestCase {
  @MainActor
  func testOpenConfigurationActivatesTheTarget() {
    let configuration = ForegroundActivation.openConfiguration()
    XCTAssertTrue(configuration.activates)
    XCTAssertTrue(configuration.addsToRecentItems)
  }

  @MainActor
  func testIgnoringOtherAppsIncludesTheLegacyFlag() {
    XCTAssertTrue(ForegroundActivation.ignoringOtherApps.contains(.activateIgnoringOtherApps))
    XCTAssertTrue(ForegroundActivation.ignoringOtherApps.contains(.activateAllWindows))
  }
}

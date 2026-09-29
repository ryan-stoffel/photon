import PhotonApps
import XCTest

final class ApplicationIndexTests: XCTestCase {
  func testSystemFinderIsIndexed() {
    let index = ApplicationIndex()
    index.refresh()

    let finder = index.applications.first {
      $0.id.caseInsensitiveCompare("app:com.apple.finder") == .orderedSame
    }
    XCTAssertNotNil(finder)
    XCTAssertTrue(finder?.name.caseInsensitiveCompare("Finder") == .orderedSame)
  }
}

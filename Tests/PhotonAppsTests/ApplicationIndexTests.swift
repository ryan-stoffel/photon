import Foundation
import XCTest
@testable import PhotonApps

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

  func testAppsFoundUnderTwoRootsAppearOnce() {
    setenv("PHOTON_APPLICATIONS_EXTRA", "/System/Applications", 1)
    defer { unsetenv("PHOTON_APPLICATIONS_EXTRA") }
    let index = ApplicationIndex()
    index.refresh()

    let ids = index.applications.map(\.id)
    XCTAssertEqual(Set(ids).count, ids.count)
  }

  func testAppNamesUseTheFinderNameAndKeepOtherNamesAsKeywords() {
    let code = ApplicationIndex.appNames(
      localizedName: "Visual Studio Code.app",
      fileName: "Visual Studio Code",
      bundleNames: ["Code", "Code"]
    )
    XCTAssertEqual(code.title, "Visual Studio Code")
    XCTAssertEqual(code.keywords, ["Code"])

    let safari = ApplicationIndex.appNames(
      localizedName: "Safari.app",
      fileName: "Safari",
      bundleNames: ["Safari", nil]
    )
    XCTAssertEqual(safari.title, "Safari")
    XCTAssertEqual(safari.keywords, [], "no bundle id, path or duplicate of the title")

    let localized = ApplicationIndex.appNames(
      localizedName: "Kalender",
      fileName: "Calendar",
      bundleNames: ["Kalender"]
    )
    XCTAssertEqual(localized.title, "Kalender")
    XCTAssertEqual(localized.keywords, ["Calendar"])

    XCTAssertEqual(ApplicationIndex.appNames(localizedName: nil, fileName: "Tool", bundleNames: []).title, "Tool")
  }
}

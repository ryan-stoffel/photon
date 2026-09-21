import AppKit
import PhotonApps
import PhotonCore
import XCTest

final class RunningApplicationsTests: XCTestCase {
  @MainActor
  func testRefreshPublishesBundleIdentifiersWithoutCrashing() {
    let monitor = RunningApplications()
    monitor.refresh()
    XCTAssertFalse(monitor.bundleIdentifiers.contains { $0.isEmpty })
  }

  func testLauncherRowIgnoresPanesEvenWhenTheBundleIsRunning() {
    let pane = LauncherRow(command: Command(
      id: "pane:com.apple.Accessibility-Settings.extension",
      title: "Accessibility",
      providerID: "apps"
    ))
    XCTAssertFalse(pane.showsRunningIndicator(runningBundleIDs: ["com.apple.Accessibility-Settings.extension"]))
  }
}

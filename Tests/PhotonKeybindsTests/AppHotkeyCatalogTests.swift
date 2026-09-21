import PhotonKeybinds
import XCTest

final class AppHotkeyCatalogTests: XCTestCase {
  func testListsInstalledAppsAndPutsRunningFirst() {
    let rows = AppHotkeyCatalog.rows(
      installed: [
        AppHotkeyNamedApp(bundleIdentifier: "com.apple.Safari", name: "Safari"),
        AppHotkeyNamedApp(bundleIdentifier: "com.apple.mail", name: "Mail"),
        AppHotkeyNamedApp(bundleIdentifier: "com.anthropic.claudefordesktop", name: "Claude"),
      ],
      running: [
        AppHotkeyNamedApp(bundleIdentifier: "com.anthropic.claudefordesktop", name: "Claude"),
      ],
      saved: []
    )
    XCTAssertEqual(rows.map(\.name), ["Claude", "Mail", "Safari"])
    XCTAssertEqual(rows.map(\.isRunning), [true, false, false])
    XCTAssertTrue(rows.allSatisfy { !$0.isExtra })
  }

  func testIncludesASavedAppThatIsMissingFromTheCatalog() {
    let saved = AppHotkey(
      bundleIdentifier: "com.example.missing",
      name: "Missing App",
      shortcut: KeyShortcut(keyCode: 8, modifiers: .hyper)
    )
    let rows = AppHotkeyCatalog.rows(
      installed: [AppHotkeyNamedApp(bundleIdentifier: "com.apple.Safari", name: "Safari")],
      running: [],
      saved: [saved]
    )
    XCTAssertEqual(rows.map(\.name), ["Missing App", "Safari"])
    XCTAssertEqual(rows.first?.isExtra, true)
    XCTAssertEqual(rows.last?.isExtra, false)
  }

  func testRunningAppNotInApplicationsStillAppears() {
    let rows = AppHotkeyCatalog.rows(
      installed: [AppHotkeyNamedApp(bundleIdentifier: "com.apple.Safari", name: "Safari")],
      running: [AppHotkeyNamedApp(bundleIdentifier: "com.apple.calculator", name: "Calculator")],
      saved: []
    )
    XCTAssertEqual(rows.map(\.bundleIdentifier), ["com.apple.calculator", "com.apple.Safari"])
    XCTAssertEqual(rows.first?.isRunning, true)
    XCTAssertEqual(rows.first?.isExtra, false)
  }
}

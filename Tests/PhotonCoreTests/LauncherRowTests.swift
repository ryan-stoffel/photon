import PhotonCore
import XCTest

final class LauncherRowTests: XCTestCase {
  func testAppRowIsNameAndIconOnly() {
    let row = LauncherRow(command: Command(
      id: "app:com.apple.Safari",
      title: "Safari",
      keywords: ["com.apple.Safari"],
      providerID: "apps",
      icon: .fileIcon(path: "/Applications/Safari.app")
    ))
    XCTAssertEqual(row.title, "Safari")
    XCTAssertNil(row.detail)
    XCTAssertEqual(row.icon, .fileIcon(path: "/Applications/Safari.app"))
  }

  func testMeaningfulSubtitleBecomesDetail() {
    let pane = LauncherRow(command: Command(
      id: "pane:x", title: "Accessibility", subtitle: "System Settings", providerID: "apps"
    ))
    XCTAssertEqual(pane.detail, "System Settings")

    let file = LauncherRow(command: Command(
      id: "file:/Users/ryan/Documents/report.pdf",
      title: "report.pdf",
      subtitle: "~/Documents",
      providerID: "files"
    ))
    XCTAssertEqual(file.detail, "~/Documents")
  }

  func testBlankSubtitleIsDropped() {
    let row = LauncherRow(command: Command(id: "x", title: "X", subtitle: "   \n ", providerID: "test"))
    XCTAssertNil(row.detail)
  }

  func testSubtitleRepeatingTheTitleIsDropped() {
    let row = LauncherRow(command: Command(id: "x", title: "Notes", subtitle: "notes", providerID: "notes"))
    XCTAssertNil(row.detail)
  }

  func testMultilinePreviewCollapsesToOneLine() {
    let row = LauncherRow(command: Command(
      id: "note:1",
      title: "Groceries",
      subtitle: "milk\n  eggs\t\tbread  ",
      providerID: "notes"
    ))
    XCTAssertEqual(row.detail, "milk eggs bread")
  }

  func testAccessoryNamesTheResultType() {
    func accessory(_ id: String, _ providerID: String) -> String? {
      LauncherRow(command: Command(id: id, title: "X", providerID: providerID)).accessory
    }
    XCTAssertEqual(accessory("app:com.apple.Safari", "apps"), "Application")
    XCTAssertEqual(accessory("pane:com.apple.Accessibility-Settings.extension", "apps"), "Command")
    XCTAssertEqual(accessory("file:/Users/ryan/report.pdf", "files"), "File")
    XCTAssertEqual(accessory("files:search", "files"), "Command")
    XCTAssertEqual(accessory("note:1", "notes"), "Note")
    XCTAssertNil(accessory("calculator:x", "calculator"))
  }

  func testRowIdentityFollowsTheCommand() {
    let command = Command(id: "clipboard:history", title: "Clipboard History", providerID: "clipboard")
    XCTAssertEqual(LauncherRow(command: command).id, command.id)
  }

  func testOnlyRunningAppsShowADockDot() {
    let safari = LauncherRow(command: Command(
      id: "app:com.apple.Safari",
      title: "Safari",
      providerID: "apps"
    ))
    let pane = LauncherRow(command: Command(
      id: "pane:com.apple.Accessibility-Settings.extension",
      title: "Accessibility",
      subtitle: "System Settings",
      providerID: "apps"
    ))
    let note = LauncherRow(command: Command(id: "note:1", title: "Groceries", providerID: "notes"))
    let file = LauncherRow(command: Command(
      id: "file:/Users/ryan/Documents/report.pdf",
      title: "report.pdf",
      providerID: "files"
    ))
    let window = LauncherRow(command: Command(id: "window:leftHalf", title: "Left Half", providerID: "keybinds"))
    let running = Set(["com.apple.Safari", "com.apple.finder"])

    XCTAssertEqual(safari.applicationBundleIdentifier, "com.apple.Safari")
    XCTAssertTrue(safari.showsRunningIndicator(runningBundleIDs: running))
    XCTAssertFalse(safari.showsRunningIndicator(runningBundleIDs: ["com.apple.finder"]))
    XCTAssertNil(pane.applicationBundleIdentifier)
    XCTAssertFalse(pane.showsRunningIndicator(runningBundleIDs: running))
    XCTAssertFalse(note.showsRunningIndicator(runningBundleIDs: running))
    XCTAssertFalse(file.showsRunningIndicator(runningBundleIDs: running))
    XCTAssertFalse(window.showsRunningIndicator(runningBundleIDs: running))
  }
}

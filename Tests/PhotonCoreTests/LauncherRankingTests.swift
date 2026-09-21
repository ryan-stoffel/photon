import PhotonCore
import XCTest

final class LauncherRankingTests: XCTestCase {
  func testRunningAppsLeadThenTheRestKeepRelativeOrder() {
    let safari = command("app:com.apple.Safari", title: "Safari", provider: "apps")
    let notes = command("note:1", title: "Groceries", provider: "notes")
    let calc = command("app:com.apple.calculator", title: "Calculator", provider: "apps")
    let file = command("file:/tmp/a.pdf", title: "a.pdf", provider: "files")
    let mail = command("app:com.apple.mail", title: "Mail", provider: "apps")
    let ranked = [safari, notes, calc, file, mail].map { RankedCommand(command: $0, textScore: 1, frecencyScore: 0) }

    let ordered = LauncherRanking.promotingRunningApps(
      ranked,
      runningBundleIDs: ["com.apple.calculator", "com.apple.Safari"]
    )
    XCTAssertEqual(ordered.map(\.id), [
      "app:com.apple.Safari",
      "app:com.apple.calculator",
      "note:1",
      "file:/tmp/a.pdf",
      "app:com.apple.mail",
    ])
  }

  func testFilesNotesAndPanesNeverCountAsRunningApps() {
    let pane = command(
      "pane:com.apple.Accessibility-Settings.extension",
      title: "Accessibility",
      provider: "apps"
    )
    let file = command("file:/tmp/a.pdf", title: "a.pdf", provider: "files")
    let note = command("note:1", title: "Groceries", provider: "notes")
    let window = command("window:leftHalf", title: "Left Half", provider: "keybinds")
    let ranked = [pane, file, note, window].map { RankedCommand(command: $0, textScore: 1, frecencyScore: 0) }

    let ordered = LauncherRanking.promotingRunningApps(
      ranked,
      runningBundleIDs: [
        "com.apple.Accessibility-Settings.extension",
        "file:/tmp/a.pdf",
        "note:1",
        "window:leftHalf",
      ]
    )
    XCTAssertEqual(ordered.map(\.id), ranked.map(\.id))
  }

  func testEmptyRunningSetLeavesOrderUnchanged() {
    let safari = RankedCommand(
      command: command("app:com.apple.Safari", title: "Safari", provider: "apps"),
      textScore: 1,
      frecencyScore: 0
    )
    XCTAssertEqual(LauncherRanking.promotingRunningApps([safari], runningBundleIDs: []).map(\.id), [safari.id])
  }

  private func command(_ id: String, title: String, provider: String) -> Command {
    Command(id: id, title: title, providerID: provider)
  }
}

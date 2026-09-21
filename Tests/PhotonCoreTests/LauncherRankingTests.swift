import PhotonCore
import XCTest

final class LauncherRankingTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  func testSuggestionsRankAppsByUseCountNotPosition() {
    let safari = command("app:com.apple.Safari", title: "Safari", provider: "apps")
    let notes = command("note:1", title: "Groceries", provider: "notes")
    let calc = command("app:com.apple.calculator", title: "Calculator", provider: "apps")
    let file = command("file:/tmp/a.pdf", title: "a.pdf", provider: "files")
    let mail = command("app:com.apple.mail", title: "Mail", provider: "apps")
    let ranked = [safari, notes, calc, file, mail].map {
      RankedCommand(command: $0, textScore: 1, frecencyScore: 0)
    }
    let usage: [String: LauncherRanking.Usage] = [
      safari.id: LauncherRanking.Usage(count: 2, lastUsed: now),
      notes.id: LauncherRanking.Usage(count: 40, lastUsed: now),
      calc.id: LauncherRanking.Usage(count: 9, lastUsed: now.addingTimeInterval(-60)),
      file.id: LauncherRanking.Usage(count: 30, lastUsed: now),
      mail.id: LauncherRanking.Usage(count: 9, lastUsed: now),
    ]

    let suggested = LauncherRanking.suggestedApps(from: ranked, usage: usage)
    XCTAssertEqual(suggested.map(\.id), [mail.id, calc.id, safari.id])
  }

  func testFilesNotesPanesAndCommandsStayOutOfSuggestions() {
    let pane = command(
      "pane:com.apple.Accessibility-Settings.extension",
      title: "Accessibility",
      provider: "apps"
    )
    let file = command("file:/tmp/a.pdf", title: "a.pdf", provider: "files")
    let note = command("note:1", title: "Groceries", provider: "notes")
    let window = command("window:leftHalf", title: "Left Half", provider: "keybinds")
    let ranked = [pane, file, note, window].map {
      RankedCommand(command: $0, textScore: 1, frecencyScore: 0)
    }
    let usage = Dictionary(uniqueKeysWithValues: ranked.map {
      ($0.id, LauncherRanking.Usage(count: 12, lastUsed: now))
    })

    XCTAssertTrue(LauncherRanking.suggestedApps(from: ranked, usage: usage).isEmpty)
  }

  func testAppsThatHaveNeverBeenOpenedAreOmitted() {
    let safari = command("app:com.apple.Safari", title: "Safari", provider: "apps")
    let mail = command("app:com.apple.mail", title: "Mail", provider: "apps")
    let ranked = [safari, mail].map { RankedCommand(command: $0, textScore: 1, frecencyScore: 0) }
    let usage = [mail.id: LauncherRanking.Usage(count: 1, lastUsed: now)]

    XCTAssertEqual(LauncherRanking.suggestedApps(from: ranked, usage: usage).map(\.id), [mail.id])
  }

  func testSuggestionListStopsAtTheLimit() {
    let ranked = (0 ..< 10).map { index in
      RankedCommand(
        command: command("app:example.\(index)", title: "App \(index)", provider: "apps"),
        textScore: 1,
        frecencyScore: 0
      )
    }
    let usage = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { index, item in
      (item.id, LauncherRanking.Usage(count: 10 - index, lastUsed: now))
    })

    let suggested = LauncherRanking.suggestedApps(from: ranked, usage: usage, limit: 6)
    XCTAssertEqual(suggested.count, 6)
    XCTAssertEqual(suggested.first?.id, "app:example.0")
  }

  private func command(_ id: String, title: String, provider: String) -> Command {
    Command(id: id, title: title, providerID: provider)
  }
}

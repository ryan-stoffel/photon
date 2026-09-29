import PhotonCore
import XCTest

final class LauncherRankingTests: XCTestCase {
  private let now = Date(timeIntervalSince1970: 1_800_000_000)

  func testSuggestionsRankAppsAndCommandsByUseCountNotPosition() {
    let safari = command("app:com.apple.Safari", title: "Safari", provider: "apps")
    let notes = command("note:1", title: "Groceries", provider: "notes")
    let clipboard = command("clipboard:history", title: "Clipboard History", provider: "clipboard")
    let calc = command("app:com.apple.calculator", title: "Calculator", provider: "apps")
    let file = command("file:/tmp/a.pdf", title: "a.pdf", provider: "files")
    let mail = command("app:com.apple.mail", title: "Mail", provider: "apps")
    let searchFiles = command("files:search", title: "Search Files", provider: "files")
    let ranked = [safari, notes, clipboard, calc, file, mail, searchFiles].map {
      RankedCommand(command: $0, textScore: 1, frecencyScore: 0)
    }
    let usage: [String: LauncherRanking.Usage] = [
      safari.id: LauncherRanking.Usage(count: 2, lastUsed: now),
      notes.id: LauncherRanking.Usage(count: 40, lastUsed: now),
      clipboard.id: LauncherRanking.Usage(count: 30, lastUsed: now),
      calc.id: LauncherRanking.Usage(count: 9, lastUsed: now.addingTimeInterval(-60)),
      file.id: LauncherRanking.Usage(count: 50, lastUsed: now),
      mail.id: LauncherRanking.Usage(count: 9, lastUsed: now),
      searchFiles.id: LauncherRanking.Usage(count: 12, lastUsed: now),
    ]

    let suggested = LauncherRanking.suggestions(from: ranked, usage: usage)
    XCTAssertEqual(
      suggested.map(\.id),
      [clipboard.id, searchFiles.id, mail.id, calc.id, safari.id]
    )
  }

  func testFilesNotesAndPanesStayOutOfSuggestions() {
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

    XCTAssertEqual(LauncherRanking.suggestions(from: ranked, usage: usage).map(\.id), [window.id])
  }

  func testAppsAndCommandsThatHaveNeverBeenOpenedAreOmitted() {
    let safari = command("app:com.apple.Safari", title: "Safari", provider: "apps")
    let mail = command("app:com.apple.mail", title: "Mail", provider: "apps")
    let clipboard = command("clipboard:history", title: "Clipboard History", provider: "clipboard")
    let notes = command("notes.open", title: "Notes", provider: "notes")
    let ranked = [safari, mail, clipboard, notes].map {
      RankedCommand(command: $0, textScore: 1, frecencyScore: 0)
    }
    let usage = [
      mail.id: LauncherRanking.Usage(count: 1, lastUsed: now),
      notes.id: LauncherRanking.Usage(count: 4, lastUsed: now),
    ]

    XCTAssertEqual(
      LauncherRanking.suggestions(from: ranked, usage: usage).map(\.id),
      [notes.id, mail.id]
    )
  }

  func testApplicationStaysAboveSearchFilesAndFilenameHits() {
    let search = RankedCommand(
      command: command("files:search", title: "Search Files", provider: "files"),
      textScore: 5,
      frecencyScore: 0
    )
    let finder = RankedCommand(
      command: command("app:com.apple.finder", title: "Finder", provider: "apps"),
      textScore: 1,
      frecencyScore: 0
    )
    let file = RankedCommand(
      command: command("file:/tmp/finder.js", title: "finder.js", provider: "files"),
      textScore: 0.9,
      frecencyScore: 0
    )

    let ordered = LauncherRanking.applicationsBeforeFileHits([search, finder, file])

    XCTAssertEqual(ordered.map(\.id), [finder.id, search.id, file.id])
  }

  func testFileHitsStayInScoreOrderWhenNoApplicationMatches() {
    let search = RankedCommand(
      command: command("files:search", title: "Search Files", provider: "files"),
      textScore: 5,
      frecencyScore: 0
    )
    let file = RankedCommand(
      command: command("file:/tmp/ember.pdf", title: "Ember.pdf", provider: "files"),
      textScore: 1,
      frecencyScore: 0
    )
    let pane = RankedCommand(
      command: command("pane:com.apple.General", title: "General", provider: "apps"),
      textScore: 0.4,
      frecencyScore: 0
    )

    let ordered = LauncherRanking.applicationsBeforeFileHits([search, file, pane])

    XCTAssertEqual(ordered.map(\.id), [search.id, file.id, pane.id])
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

    let suggested = LauncherRanking.suggestions(from: ranked, usage: usage, limit: 6)
    XCTAssertEqual(suggested.count, 6)
    XCTAssertEqual(suggested.first?.id, "app:example.0")
  }

  private func command(_ id: String, title: String, provider: String) -> Command {
    Command(id: id, title: title, providerID: provider)
  }
}

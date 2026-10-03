import PhotonCore
import XCTest

final class CommandRegistryTests: XCTestCase {
  func testFrecencyDoesNotLiftAKeywordMatchAboveATitleMatch() async {
    let safari = command("app:com.apple.Safari", title: "Safari", keywords: ["com.apple.Safari"])
    let calendar = command("app:com.apple.iCal", title: "Calendar")
    let registry = registry(with: [safari, calendar])
    var frecency = FrecencyStore()
    frecency.recordUse(id: safari.id)

    let ranked = await registry.search("cal", frecency: frecency)

    XCTAssertEqual(ranked.map(\.id), [calendar.id, safari.id])
  }

  func testExactTitleOutranksExactKeyword() async {
    let paneKeywords = ["settings", "preferences", "system settings"]
    let panes = ["General", "Bluetooth", "Wi-Fi"].map {
      command("pane:\($0)", title: $0, keywords: paneKeywords)
    }
    let settings = command("app:com.apple.systempreferences", title: "System Settings")
    let mail = command("app:com.apple.mail", title: "Mail")
    let accounts = command("pane:com.apple.Internet-Accounts", title: "Internet Accounts", keywords: ["mail"])
    let registry = registry(with: panes + [accounts, settings, mail])

    let settingsFirst = await registry.search("system settings", frecency: FrecencyStore()).first
    let mailFirst = await registry.search("mail", frecency: FrecencyStore()).first

    XCTAssertEqual(settingsFirst?.id, settings.id)
    XCTAssertEqual(mailFirst?.id, mail.id)
  }

  private func registry(with commands: [Command]) -> CommandRegistry {
    let registry = CommandRegistry()
    registry.register(FixtureProvider(id: "apps", results: commands))
    return registry
  }

  private func command(_ id: String, title: String, keywords: [String] = []) -> Command {
    Command(id: id, title: title, keywords: keywords, providerID: "apps")
  }
}

private struct FixtureProvider: CommandProvider {
  let id: String
  let displayName = "Fixture"
  let results: [Command]

  func commands(matching _: String) async -> [Command] {
    results
  }

  func execute(_: Command) async throws {
    throw CommandRegistryError.unknownProvider(id)
  }
}

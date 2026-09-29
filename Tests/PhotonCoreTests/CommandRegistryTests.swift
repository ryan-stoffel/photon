import PhotonCore
import XCTest

final class CommandRegistryTests: XCTestCase {
  func testFinderQueryMatchesAnApplication() async {
    let registry = CommandRegistry()
    registry.register(
      FixtureProvider(
        id: "apps",
        results: [
          command("app:com.apple.finder", title: "Finder"),
          command("pane:com.apple.General", title: "General"),
        ]
      )
    )

    let matches = await registry.containsApplication(matching: "finder")

    XCTAssertTrue(matches)
  }

  func testSettingsPaneDoesNotCountAsAnApplication() async {
    let registry = CommandRegistry()
    registry.register(
      FixtureProvider(
        id: "apps",
        results: [command("pane:com.apple.General", title: "General")]
      )
    )

    let matches = await registry.containsApplication(matching: "general")

    XCTAssertFalse(matches)
  }

  func testBlankQueryDoesNotMatchAnApplication() async {
    let registry = CommandRegistry()
    registry.register(
      FixtureProvider(
        id: "apps",
        results: [command("app:com.apple.finder", title: "Finder")]
      )
    )

    let matches = await registry.containsApplication(matching: "  ")

    XCTAssertFalse(matches)
  }

  private func command(_ id: String, title: String) -> Command {
    Command(id: id, title: title, providerID: "apps")
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

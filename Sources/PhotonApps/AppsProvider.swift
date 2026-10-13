import AppKit
import PhotonCore

public final class AppsProvider: CommandProvider, @unchecked Sendable {
  public let id = "apps"
  public let displayName = "Applications"

  private let index = ApplicationIndex()

  public init() {}

  public func reload() async {
    await Task.detached(priority: .userInitiated) { [index] in
      index.refresh()
    }.value
  }

  public func commands(matching query: String) async -> [Command] {
    let apps = index.applications
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let providerID = id
    return await Task.detached(priority: .userInitiated) {
      apps.compactMap { app in
        if !trimmed.isEmpty {
          let hit = FuzzyMatcher.matches(query: trimmed, candidate: app.name)
            || app.keywords.contains { FuzzyMatcher.matches(query: trimmed, candidate: $0) }
          if !hit {
            return nil
          }
        }
        return Command(
          id: app.id,
          title: app.name,
          subtitle: app.subtitle,
          keywords: app.keywords,
          providerID: providerID,
          icon: app.icon
        )
      }
    }.value
  }

  public func execute(_ command: Command) async throws {
    let apps = index.applications
    guard let app = apps.first(where: { $0.id == command.id }) else {
      throw AppsProviderError.notFound(command.id)
    }
    try await open(app)
  }

  /// Bundle URL behind an `app:` command, for Show in Finder and Copy Path. Nil for panes and other providers.
  public func applicationURL(for command: Command) -> URL? {
    guard command.id.hasPrefix("app:") else {
      return nil
    }
    return index.applications.first { $0.id == command.id }?.url
  }

  /// Starts an `.app` launch without waiting for LaunchServices, so the launcher hides at once.
  /// Launch errors only reach the log because the panel is already gone.
  @MainActor
  private func open(_ app: IndexedApplication) throws {
    if app.url.pathExtension == "app" {
      let bundleID = bundleIdentifier(for: app)
      Task {
        do {
          try await ForegroundActivation.launch(at: app.url, bundleIdentifier: bundleID)
        } catch {
          NSLog("Photon: could not launch \(app.url.path): \(error)")
        }
      }
      return
    }
    let ok = NSWorkspace.shared.open(app.url)
    if !ok {
      throw AppsProviderError.launchFailed(app.url)
    }
  }

  private func bundleIdentifier(for app: IndexedApplication) -> String? {
    if app.id.hasPrefix("app:") {
      return String(app.id.dropFirst(4))
    }
    return Bundle(url: app.url)?.bundleIdentifier
  }
}

public enum AppsProviderError: Error, Sendable {
  case notFound(String)
  case launchFailed(URL)
}

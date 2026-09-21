import AppKit

/// Brings a launched or already-running app above everything else.
///
/// Photon is an accessory agent. Cooperative activation (`yieldActivation`) plus
/// `activateIgnoringOtherApps` is what actually puts the target in front.
@MainActor
public enum ForegroundActivation {
  public static let ignoringOtherApps: NSApplication.ActivationOptions = [
    .activateAllWindows,
    .activateIgnoringOtherApps,
  ]

  public static func openConfiguration() -> NSWorkspace.OpenConfiguration {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.addsToRecentItems = true
    return configuration
  }

  public static func yield(to bundleIdentifier: String?) {
    guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
      return
    }
    NSApp.yieldActivation(toApplicationWithBundleIdentifier: bundleIdentifier)
  }

  public static func activate(_ application: NSRunningApplication) {
    guard !application.isTerminated else {
      return
    }
    NSApp.yieldActivation(to: application)
    _ = application.activate(options: ignoringOtherApps)
    _ = application.activate(from: NSRunningApplication.current, options: ignoringOtherApps)
  }

  @discardableResult
  public static func launch(at url: URL, bundleIdentifier: String?) async throws -> NSRunningApplication {
    yield(to: bundleIdentifier)
    let running = try await NSWorkspace.shared.openApplication(at: url, configuration: openConfiguration())
    activate(running)
    return running
  }

  @discardableResult
  public static func launch(bundleIdentifier: String) async throws -> NSRunningApplication {
    if let running = runningApplication(bundleIdentifier: bundleIdentifier) {
      running.unhide()
      activate(running)
      return running
    }
    guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
      throw ForegroundActivationError.notInstalled(bundleIdentifier)
    }
    return try await launch(at: url, bundleIdentifier: bundleIdentifier)
  }

  public static func runningApplication(bundleIdentifier: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
      .first { !$0.isTerminated }
  }
}

public enum ForegroundActivationError: LocalizedError, Sendable {
  case notInstalled(String)

  public var errorDescription: String? {
    switch self {
    case let .notInstalled(bundleIdentifier):
      "No application with bundle identifier \(bundleIdentifier) is installed."
    }
  }
}

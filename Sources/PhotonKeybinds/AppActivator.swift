import AppKit

/// Launch, focus, or hide an application by bundle identifier (the app hotkey behaviour).
@MainActor
public enum AppActivator {
  /// Frontmost: hide it. Running but not frontmost: bring it forward. Not running: launch it.
  public static func toggle(bundleIdentifier: String) async throws {
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
      .first { !$0.isTerminated }

    if let running, running.isActive {
      running.hide()
      return
    }

    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
      NSApp.yieldActivation(toApplicationWithBundleIdentifier: bundleIdentifier)
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true
      configuration.addsToRecentItems = true
      let launched = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
      NSApp.yieldActivation(to: launched)
      _ = launched.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
      return
    }

    guard let running else {
      throw AppActivatorError.notInstalled(bundleIdentifier)
    }
    running.unhide()
    NSApp.yieldActivation(to: running)
    _ = running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
  }
}

public enum AppActivatorError: LocalizedError {
  case notInstalled(String)

  public var errorDescription: String? {
    switch self {
    case let .notInstalled(bundleIdentifier):
      "No application with bundle identifier \(bundleIdentifier) is installed."
    }
  }
}

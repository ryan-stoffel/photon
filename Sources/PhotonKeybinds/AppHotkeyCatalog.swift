/// One row in Settings > Keybinds > App hotkeys: an installed or running app that can take a shortcut.
public struct AppHotkeyCatalogRow: Equatable, Identifiable, Sendable {
  public var id: String {
    bundleIdentifier
  }

  public let bundleIdentifier: String
  public let name: String
  public let isRunning: Bool
  /// True when the row is only present because the user added it (or had a shortcut) and it is
  /// not in the installed/running catalog.
  public let isExtra: Bool

  public init(bundleIdentifier: String, name: String, isRunning: Bool, isExtra: Bool) {
    self.bundleIdentifier = bundleIdentifier
    self.name = name
    self.isRunning = isRunning
    self.isExtra = isExtra
  }
}

public struct AppHotkeyNamedApp: Equatable, Sendable {
  public let bundleIdentifier: String
  public let name: String

  public init(bundleIdentifier: String, name: String) {
    self.bundleIdentifier = bundleIdentifier
    self.name = name
  }
}

/// Merges installed apps, currently running apps, and saved shortcuts into one list.
public enum AppHotkeyCatalog {
  public static func rows(
    installed: [AppHotkeyNamedApp],
    running: [AppHotkeyNamedApp],
    saved: [AppHotkey]
  ) -> [AppHotkeyCatalogRow] {
    var names: [String: String] = [:]
    var installedIDs = Set<String>()
    var runningIDs = Set<String>()

    func record(_ app: AppHotkeyNamedApp, installed: Bool, running: Bool) {
      let key = canonical(app.bundleIdentifier)
      guard !key.isEmpty else {
        return
      }
      if names[key] == nil {
        names[key] = app.name
      }
      if installed {
        installedIDs.insert(key)
      }
      if running {
        runningIDs.insert(key)
      }
    }

    for app in installed {
      record(app, installed: true, running: false)
    }
    for app in running {
      record(app, installed: false, running: true)
    }
    for hotkey in saved {
      let key = canonical(hotkey.bundleIdentifier)
      guard !key.isEmpty else {
        continue
      }
      if names[key] == nil {
        names[key] = hotkey.name
      }
    }

    var keys = Array(names.keys)
    keys.sort { lhs, rhs in
      let leftRunning = runningIDs.contains(lhs)
      let rightRunning = runningIDs.contains(rhs)
      if leftRunning != rightRunning {
        return leftRunning && !rightRunning
      }
      let leftName = names[lhs] ?? lhs
      let rightName = names[rhs] ?? rhs
      let comparison = leftName.localizedCaseInsensitiveCompare(rightName)
      if comparison != .orderedSame {
        return comparison == .orderedAscending
      }
      return lhs < rhs
    }

    return keys.map { key in
      AppHotkeyCatalogRow(
        bundleIdentifier: key,
        name: names[key] ?? key,
        isRunning: runningIDs.contains(key),
        isExtra: !installedIDs.contains(key) && !runningIDs.contains(key)
      )
    }
  }

  private static func canonical(_ identifier: String) -> String {
    identifier.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

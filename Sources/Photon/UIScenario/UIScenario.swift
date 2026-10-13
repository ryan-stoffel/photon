import Foundation

/// Deterministic UI states for automated screenshots. Inert unless `PHOTON_UI_SCENARIO` or
/// `--ui-scenario` is set at launch.
enum UIScenario: Equatable, Sendable {
  case launcherEmpty
  case launcherQuery(String)
  /// Launcher with a query and the ⌘K action panel open, optionally filtered.
  case launcherActions(query: String, filter: String)
  case launcherRecs
  case clipboardEmpty
  case filesEmpty
  case filesQuery(String)
  case settings(SettingsPaneID)
  case notes

  static var current: UIScenario? {
    if let fromEnv = ProcessInfo.processInfo.environment["PHOTON_UI_SCENARIO"], !fromEnv.isEmpty {
      return parse(fromEnv)
    }
    let args = ProcessInfo.processInfo.arguments
    if let index = args.firstIndex(of: "--ui-scenario"), index + 1 < args.count {
      return parse(args[index + 1])
    }
    return nil
  }

  var isActive: Bool {
    Self.current != nil
  }

  /// Isolated Application Support root (`PHOTON_ISOLATED_DATA_ROOT`).
  static var isolatedDataRoot: URL? {
    guard current != nil else {
      return nil
    }
    guard let path = ProcessInfo.processInfo.environment["PHOTON_ISOLATED_DATA_ROOT"], !path.isEmpty else {
      return nil
    }
    return URL(fileURLWithPath: path, isDirectory: true)
  }

  /// When set, the app writes `ready` here once the scenario UI has settled.
  static var readyMarkerURL: URL? {
    guard let path = ProcessInfo.processInfo.environment["PHOTON_UI_SCENARIO_READY_PATH"], !path.isEmpty else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  /// When set, the app writes the `CGWindow` number to capture for this scenario.
  static var windowIDMarkerURL: URL? {
    guard let path = ProcessInfo.processInfo.environment["PHOTON_UI_SCENARIO_WINDOW_ID_PATH"], !path.isEmpty else {
      return nil
    }
    return URL(fileURLWithPath: path)
  }

  private static func parse(_ raw: String) -> UIScenario? {
    switch raw {
    case "launcher-empty": .launcherEmpty
    case "launcher-recs": .launcherRecs
    case "clipboard-empty": .clipboardEmpty
    case "files-empty": .filesEmpty
    case "notes": .notes
    case "calculator": .launcherQuery("2 + 2")
    default: parsePrefixed(raw)
    }
  }

  /// Scenarios that carry a value after a `name:` prefix.
  private static func parsePrefixed(_ raw: String) -> UIScenario? {
    if raw.hasPrefix("launcher-query:") {
      return .launcherQuery(String(raw.dropFirst("launcher-query:".count)))
    }
    if raw.hasPrefix("launcher-actions:") {
      // launcher-actions:<query>[|<action filter>]
      let parts = raw.dropFirst("launcher-actions:".count).split(separator: "|", maxSplits: 1)
      return .launcherActions(
        query: parts.first.map(String.init) ?? "",
        filter: parts.count > 1 ? String(parts[1]) : ""
      )
    }
    if raw.hasPrefix("files-query:") {
      return .filesQuery(String(raw.dropFirst("files-query:".count)))
    }
    if raw.hasPrefix("settings:") {
      return SettingsPaneID(rawValue: String(raw.dropFirst("settings:".count))).map { .settings($0) }
    }
    return nil
  }
}

enum SettingsPaneID: String, Hashable, Sendable, CaseIterable, Identifiable {
  case general
  case appearance
  case clipboard
  case notes
  case files
  case keybinds
  case about

  var id: String {
    rawValue
  }

  var title: String {
    switch self {
    case .general: "General"
    case .appearance: "Appearance"
    case .clipboard: "Clipboard"
    case .notes: "Notes"
    case .files: "Files"
    case .keybinds: "Keybinds"
    case .about: "About"
    }
  }

  var symbolName: String {
    switch self {
    case .general: "gearshape"
    case .appearance: "paintpalette"
    case .clipboard: "clipboard"
    case .notes: "note.text"
    case .files: "folder"
    case .keybinds: "keyboard"
    case .about: "info.circle"
    }
  }
}

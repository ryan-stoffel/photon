import Foundation

/// What one launcher result row shows. A pure mapping from `Command` so the
/// rules (what counts as a subtitle worth showing) can be tested without AppKit.
public struct LauncherRow: Identifiable, Hashable, Sendable {
  public let id: String
  public let title: String
  /// Secondary text next to the title, or `nil` when the command has nothing worth adding.
  public let detail: String?
  public let icon: CommandIcon?
  public let providerID: String

  public init(command: Command) {
    id = command.id
    title = Self.singleLine(command.title)
    detail = Self.detail(for: command)
    icon = command.icon
    providerID = command.providerID
  }

  /// Bundle ID for Dock-style running dots. Real apps only; never panes, files, notes, or commands.
  public var applicationBundleIdentifier: String? {
    Self.applicationBundleIdentifier(commandID: id, providerID: providerID)
  }

  /// True when this row is an application that is currently running.
  public func showsRunningIndicator(runningBundleIDs: Set<String>) -> Bool {
    guard let identifier = applicationBundleIdentifier else {
      return false
    }
    return runningBundleIDs.contains { $0.caseInsensitiveCompare(identifier) == .orderedSame }
  }

  public static func applicationBundleIdentifier(commandID: String, providerID: String) -> String? {
    guard providerID == "apps", commandID.hasPrefix("app:") else {
      return nil
    }
    let identifier = String(commandID.dropFirst(4))
    return identifier.isEmpty ? nil : identifier
  }

  /// Verb for the footer hint: window commands run, calculator copies, everything else opens.
  public var actionVerb: String {
    switch providerID {
    case "keybinds": "Run"
    case "calculator": "Copy Answer"
    default: "Open"
    }
  }

  /// A subtitle is shown only when it adds something: not blank and not the title again.
  static func detail(for command: Command) -> String? {
    let subtitle = singleLine(command.subtitle)
    guard !subtitle.isEmpty, subtitle.caseInsensitiveCompare(command.title) != .orderedSame else {
      return nil
    }
    return subtitle
  }

  /// Collapses newlines and runs of whitespace; note previews may span lines.
  static func singleLine(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }
}

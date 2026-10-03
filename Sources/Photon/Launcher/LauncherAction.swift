import AppKit

/// One entry in the ⌘K action panel. The first action of a list is the primary (↵) action
/// the footer names. `shortcut` is drawn as keycaps and runs the action when pressed while
/// the launcher is key, whether or not the panel is open.
struct LauncherAction: Identifiable {
  let id: String
  let title: String
  /// SF Symbol name for the panel row.
  var symbol: String?
  var shortcut: LauncherShortcut?
  /// Drawn in red, like Raycast's Delete / Move to Trash.
  var isDestructive = false
  /// Runs the action. Returns true when the launcher should hide afterwards.
  let run: @MainActor () async -> Bool
}

/// A key equivalent: a virtual key code plus device-independent modifiers.
struct LauncherShortcut: Equatable {
  let keyCode: UInt16
  let modifiers: NSEvent.ModifierFlags
  /// Glyph drawn on the key's cap, for example "↵", "K", "⌫".
  let key: String

  static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

  /// Caps Lock, Fn, and numeric-pad flags never affect the match.
  func matches(_ event: NSEvent) -> Bool {
    event.keyCode == keyCode
      && event.modifierFlags.intersection(Self.relevantModifiers) == modifiers.intersection(Self.relevantModifiers)
  }

  /// Keycap labels in macOS order: ⌃ ⌥ ⇧ ⌘ then the key.
  var glyphs: [String] {
    var result: [String] = []
    if modifiers.contains(.control) {
      result.append("⌃")
    }
    if modifiers.contains(.option) {
      result.append("⌥")
    }
    if modifiers.contains(.shift) {
      result.append("⇧")
    }
    if modifiers.contains(.command) {
      result.append("⌘")
    }
    result.append(key)
    return result
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.keyCode == rhs.keyCode
      && lhs.key == rhs.key
      && lhs.modifiers.intersection(relevantModifiers) == rhs.modifiers.intersection(relevantModifiers)
  }
}

extension LauncherShortcut {
  static let returnKey = LauncherShortcut(keyCode: 36, modifiers: [], key: "↵")
  static let commandReturn = LauncherShortcut(keyCode: 36, modifiers: .command, key: "↵")
  static let actionPanel = LauncherShortcut(keyCode: 40, modifiers: .command, key: "K")
}

import AppKit

/// One entry in the ⌘K action panel. `shortcut` is drawn as keycaps and runs the action when
/// pressed while the launcher is key, whether or not the panel is open.
///
/// Rules for every action list:
/// - `actions[0]` is the primary action and its shortcut is nil. ↵ keeps running it through
///   `runSelection()` / `performPrimaryAction()`, so its `run` must do the same thing. The footer
///   shows its title.
/// - Every other shortcut includes ⌘ or ⌃. Reserved: ↵ ↑ ↓ Esc ⌫ ⌘K ⌘W ⌘A ⌘C ⌘V ⌘X ⌘Z ⇧⌘Z ⌃N ⌃P
///   PgUp PgDn Home End.
/// - Building the list does no IO. `run` returns true to hide, and dispatch hides with
///   `restorePrevious: false`.
/// - Ids are "<area>.<verb>", for example "app.showInFinder" or "file.copyPath".
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

/// A key equivalent: a virtual key code plus device-independent modifiers. See `matches` for letter keys.
struct LauncherShortcut: Equatable {
  let keyCode: UInt16
  let modifiers: NSEvent.ModifierFlags
  /// Glyph drawn on the key's cap, for example "↵", "K", "⌫".
  let key: String

  static let relevantModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command]

  /// Letters match by character so other keyboard layouts keep working. Other keys, and letters
  /// typed on a non-Latin layout, match by key code. Caps Lock, Fn, and numeric-pad flags never
  /// affect the match. Keypad Enter (76) counts as Return (36).
  func matches(_ event: NSEvent) -> Bool {
    guard event.modifierFlags.intersection(Self.relevantModifiers) == modifiers.intersection(Self.relevantModifiers)
    else {
      return false
    }
    if let letter = Self.asciiLetter(key), let typed = event.charactersIgnoringModifiers.flatMap(Self.asciiLetter) {
      return typed == letter
    }
    let eventKey = event.keyCode == 76 ? 36 : event.keyCode
    return eventKey == keyCode
  }

  /// The lowercased letter when `text` is a single ASCII letter.
  private static func asciiLetter(_ text: String) -> Character? {
    guard text.count == 1, let character = text.lowercased().first, character.isASCII, character.isLetter else {
      return nil
    }
    return character
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

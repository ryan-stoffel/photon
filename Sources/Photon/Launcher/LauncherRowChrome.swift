import PhotonClipboard
import PhotonCore
import PhotonKeybinds
import PhotonNotes

/// Running-dot and keybind-chip decoration for one launcher row.
enum LauncherRowChrome {
  static func shortcutChips(
    commandID: String,
    keybinds: KeybindsConfiguration,
    clipboardHotkeyEnabled: Bool,
    clipboardHotkey: HotkeyCombo,
    notesHotkey: HotkeyCombo?
  ) -> [String] {
    if let shortcut = keybinds.shortcut(forCommandID: commandID) {
      return shortcut.chipLabels
    }
    if commandID == ClipboardProvider.historyCommandID, clipboardHotkeyEnabled {
      return KeyShortcut(clipboardHotkey).chipLabels
    }
    if commandID == NotesProvider.openCommandID, let notesHotkey {
      return KeyShortcut(notesHotkey).chipLabels
    }
    return []
  }
}

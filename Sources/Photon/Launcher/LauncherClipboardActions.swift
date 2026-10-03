import AppKit
import PhotonClipboard

extension LauncherViewModel {
  /// Actions for the selected clipboard entry, primary (↵) first, for the ⌘K panel and shortcut
  /// dispatch. Every `run` returns false: paste and copy dismiss the panel themselves, and the
  /// rest keep the clipboard open.
  func clipboardActions() -> [LauncherAction] {
    guard let clipboard, let item = clipboard.selectedItem else {
      return []
    }
    let primary = clipboard.manager.settings.pasteBehavior
    return [
      LauncherAction(id: "clipboard.\(primary.rawValue)", title: primary.label, symbol: symbol(for: primary)) {
        await clipboard.performPrimaryAction()
        return false
      },
      LauncherAction(
        id: "clipboard.\(primary.other.rawValue)",
        title: primary.other.label,
        symbol: symbol(for: primary.other),
        shortcut: .commandReturn
      ) {
        await clipboard.performSecondaryAction()
        return false
      },
      LauncherAction(
        id: "clipboard.pin",
        title: item.isPinned ? "Unpin Entry" : "Pin Entry",
        symbol: item.isPinned ? "pin.slash" : "pin",
        shortcut: LauncherShortcut(keyCode: 35, modifiers: [.shift, .command], key: "P")
      ) {
        clipboard.togglePin(item)
        return false
      },
      LauncherAction(
        id: "clipboard.delete",
        title: "Delete Entry",
        symbol: "trash",
        shortcut: LauncherShortcut(keyCode: 7, modifiers: .control, key: "X"),
        isDestructive: true
      ) {
        clipboard.delete(item)
        return false
      },
      LauncherAction(
        id: "clipboard.deleteAll",
        title: "Delete All Entries",
        symbol: "xmark.bin",
        shortcut: LauncherShortcut(keyCode: 7, modifiers: [.control, .shift], key: "X"),
        isDestructive: true
      ) {
        clipboard.requestClearAll()
        return false
      },
    ]
  }

  private func symbol(for behavior: ClipboardPasteBehavior) -> String {
    behavior == .paste ? "doc.on.clipboard" : "doc.on.doc"
  }
}

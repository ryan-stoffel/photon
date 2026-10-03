import AppKit
import PhotonClipboard
import PhotonCore

// MARK: Keys

extension LauncherPanelController {
  func startMonitor() {
    stopMonitor()
    panel?.keyDownHandler = { [weak self] event in
      guard let self else {
        return false
      }
      // While an input method composes, Return, arrows and Esc belong to it.
      if let editor = panel?.firstResponder as? NSTextView, editor.hasMarkedText() {
        return false
      }
      if LauncherShortcut.actionPanel.matches(event) {
        model.toggleActions()
        return true
      }
      if let action = shortcutAction(for: event) {
        run(action)
        return true
      }
      if model.showsActions {
        // Typing and editing keys fall through to the action filter field.
        return handleActionPanelKey(event)
      }
      switch model.session {
      case .clipboard:
        return handleClipboardKey(event) == nil
      case .commands:
        return handle(event)
      }
    }
  }

  /// The current action whose shortcut matches `event`. actions[0] is the primary (↵) action and has
  /// no shortcut; runSelection() handles it. Every other shortcut includes ⌘ or ⌃, so plain typing
  /// skips building the list.
  private func shortcutAction(for event: NSEvent) -> LauncherAction? {
    guard !event.modifierFlags.isDisjoint(with: [.command, .control]) else {
      return nil
    }
    return model.currentActions.dropFirst().first { $0.shortcut?.matches(event) == true }
  }

  /// Runs an action from the ⌘K panel or its shortcut, then hides when it asks to.
  func run(_ action: LauncherAction) {
    model.showsActions = false
    Task {
      if await action.run() {
        hide(restorePrevious: false)
      }
    }
  }

  /// ⌘K panel keys: arrows move, Return runs, Esc closes. Returns false for everything else.
  private func handleActionPanelKey(_ event: NSEvent) -> Bool {
    if let delta = listDelta(for: event) {
      model.moveActionSelection(delta)
      return true
    }
    switch event.keyCode {
    case 53:
      model.showsActions = false
      return true
    case 36, 76:
      if let action = model.selectedAction {
        run(action)
      }
      return true
    default:
      return false
    }
  }

  /// Returns true when the launcher consumed the key event.
  func handle(_ event: NSEvent) -> Bool {
    if let mode = model.activeMode, mode.handle(event) {
      return true
    }
    if let delta = listDelta(for: event) {
      model.moveSelection(delta)
      return true
    }
    switch event.keyCode {
    case 53:
      escape()
      return true
    case 51 where !event.isARepeat:
      return deleteOnEmptyQuery()
    case 126:
      model.moveSelection(-1)
      return true
    case 125:
      model.moveSelection(1)
      return true
    case 36, 76:
      runSelection()
      return true
    default:
      return false
    }
  }

  /// Escape clears typed text first, then leaves the active mode, then hides the launcher.
  func escape() {
    if !model.query.isEmpty {
      model.query = ""
    } else if model.activeMode != nil {
      model.exitMode()
    } else {
      hide()
    }
  }

  /// A fresh Backspace on an empty query leaves the active mode, like deleting a token.
  func deleteOnEmptyQuery() -> Bool {
    guard model.activeMode != nil, model.query.isEmpty else {
      return false
    }
    model.exitMode()
    return true
  }

  func runSelection() {
    Task {
      if await model.runSelection() {
        hide(restorePrevious: false)
      }
    }
  }

  /// Clipboard session: the clipboard view model owns navigation and actions.
  /// Esc clears the filter, then returns to the command list. A fresh Delete on an empty query does too.
  func handleClipboardKey(_ event: NSEvent) -> NSEvent? {
    guard let clipboard = model.clipboard else {
      return handle(event) ? nil : event
    }
    if handleClipboardListNavigation(event, clipboard: clipboard) {
      return nil
    }
    if clipboard.handleKeyDown(event) {
      return nil
    }
    let command = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command)
    switch event.keyCode {
    case 53:
      if model.query.isEmpty {
        model.exitClipboard()
      } else {
        model.query = ""
      }
      return nil
    case 51 where !command && model.query.isEmpty && !event.isARepeat:
      model.exitClipboard()
      return nil
    default:
      return event
    }
  }

  /// Up/Down (and typical list keys) move through clipboard items. Returning true
  /// swallows the event so the search field cannot steal arrow keys.
  func handleClipboardListNavigation(_ event: NSEvent, clipboard: ClipboardHistoryViewModel) -> Bool {
    if let delta = listDelta(for: event) {
      model.moveSelection(delta)
      return true
    }
    return handleClipboardListJump(event, clipboard: clipboard)
  }

  /// List movement shared by every list: arrows, ⌃N/⌃P and Page Up/Down. Nil for other keys.
  func listDelta(for event: NSEvent) -> Int? {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard !flags.contains(.command), !flags.contains(.option) else {
      return nil
    }
    let control = flags.contains(.control)
    switch event.keyCode {
    case 125:
      return 1
    case 45 where control:
      return 1
    case 126:
      return -1
    case 35 where control:
      return -1
    case 121:
      return LauncherLayout.maxVisibleRows
    case 116:
      return -LauncherLayout.maxVisibleRows
    default:
      return nil
    }
  }

  func handleClipboardListJump(_ event: NSEvent, clipboard: ClipboardHistoryViewModel) -> Bool {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard !flags.contains(.command), !flags.contains(.option) else {
      return false
    }
    switch event.keyCode {
    case 115:
      clipboard.selectFirst()
      return true
    case 119:
      clipboard.selectLast()
      return true
    default:
      return false
    }
  }

  func stopMonitor() {
    panel?.keyDownHandler = nil
  }
}

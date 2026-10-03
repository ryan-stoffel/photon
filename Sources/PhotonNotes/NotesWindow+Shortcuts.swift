import AppKit

extension NotesWindow {
  /// ⌘ letter format chords (spec §8). Letters match by character so other keyboard layouts keep working.
  private static let commandFormats: [String: MarkdownFormatStyle] = [
    "b": .bold,
    "i": .italic,
    "u": .underline,
    "e": .inlineCode,
    "l": .link,
  ]
  private static let shiftCommandFormats: [String: MarkdownFormatStyle] = ["s": .strikethrough, "b": .quote]
  private static let shiftDigitFormats: [Int: MarkdownFormatStyle] = [7: .numberedList, 8: .bulletList, 9: .checklist]
  /// keyCodes of the 1–9 keys. Digit chords match by keyCode because ⇧⌘7 arrives as "&".
  private static let digitKeyCodes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]

  func handleShortcut(_ event: NSEvent) -> Bool {
    if overlayKind != .none, handleOverlayKey(event) {
      return true
    }
    let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
    if flags.isEmpty {
      return handleUnmodifiedKey(event)
    }
    let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
    // Formatting edits the note, so it is off while the switcher or actions cover the editor.
    if overlayKind == .none || overlayKind == .format, let style = formatStyle(for: event, flags: flags, key: key) {
      applyFormat(style)
      return true
    }
    switch flags {
    case [.command]:
      return runCommand(event, key: key)
    case [.shift, .command]:
      return runShiftCommand(key)
    case [.option, .command]:
      return handleOptionCommand(event)
    case [.control] where key == "x":
      deleteFromKeyboard()
      return true
    default:
      return false
    }
  }

  /// The markdown format a chord applies, or nil.
  private func formatStyle(for event: NSEvent, flags: NSEvent.ModifierFlags, key: String) -> MarkdownFormatStyle? {
    let digit = Self.digitKeyCodes.firstIndex(of: event.keyCode).map { $0 + 1 }
    switch flags {
    case [.command]:
      return Self.commandFormats[key]
    case [.shift, .command]:
      return digit.flatMap { Self.shiftDigitFormats[$0] } ?? Self.shiftCommandFormats[key]
    case [.option, .command]:
      if let digit, digit <= 3 {
        return .heading(digit)
      }
      return key == "c" ? .codeBlock : nil
    default:
      return nil
    }
  }

  private func handleOptionCommand(_ event: NSEvent) -> Bool {
    switch event.keyCode {
    case 126:
      moveListItem(by: -1)
    case 125:
      moveListItem(by: 1)
    case 43:
      toggleFormatBar()
    default:
      return false
    }
    return true
  }

  private func handleOverlayKey(_ event: NSEvent) -> Bool {
    if event.keyCode == 53 {
      dismissOverlay()
      return true
    }
    switch overlayKind {
    case .switcher:
      return handleListKey(event, move: switcherModel.moveSelection, confirm: switcherModel.openSelection)
    case .actions:
      return handleListKey(event, move: actionsModel.moveSelection, confirm: actionsModel.runSelection)
    case .format, .none:
      return false
    }
  }

  private func handleListKey(
    _ event: NSEvent,
    move: (Int) -> Void,
    confirm: () -> Void
  ) -> Bool {
    switch event.keyCode {
    case 126:
      move(-1)
      return true
    case 125:
      move(1)
      return true
    case 36, 76:
      confirm()
      return true
    default:
      return false
    }
  }

  private func handleUnmodifiedKey(_ event: NSEvent) -> Bool {
    if event.keyCode == 53 {
      if overlayKind != .none {
        dismissOverlay()
        return true
      }
      if textView.hasMarkedText() {
        return false
      }
      // The first Esc closes the find bar, the next one hides the window.
      if scrollView.isFindBarVisible {
        performFindAction(.hideFindInterface)
        panel.makeFirstResponder(textView)
        return true
      }
      controller.hide()
      return true
    }
    return false
  }

  /// ⌘ shortcuts. ⌘, falls through to Settings, ⌘↵ toggles the caret line's task, ⌘1–9 open pinned notes.
  private func runCommand(_ event: NSEvent, key: String) -> Bool {
    if event.keyCode == 43 || key == "," {
      return false
    }
    if event.keyCode == 36 || event.keyCode == 76 {
      return textView.toggleCheckboxOnCaretLine()
    }
    if let index = Self.digitKeyCodes.firstIndex(of: event.keyCode) {
      return openPinnedNote(at: index)
    }
    return runShortcut(key)
  }

  private func runShortcut(_ key: String) -> Bool {
    switch key {
    case "k":
      toggleOverlay(.actions, present: presentActions)
    case "n":
      controller.createNote()
    case "d":
      controller.duplicateCurrentNote()
    case "p":
      toggleOverlay(.switcher, present: presentSwitcher)
    case "w":
      controller.hide()
    case "f":
      showFindBar()
    case "=", "+":
      controller.adjustFontSize(by: 1)
    case "-", "_":
      controller.adjustFontSize(by: -1)
    case "0":
      controller.resetFontSize()
    default:
      return false
    }
    return true
  }

  private func runShiftCommand(_ key: String) -> Bool {
    switch key {
    case "c":
      controller.copyCurrentNote()
    case "d":
      controller.copyDeepLink()
    case "e":
      exportCurrentNote()
    case "p":
      togglePinFromKeyboard()
    // ⌘+ and ⌘- on layouts where + and _ need Shift.
    case "+":
      controller.adjustFontSize(by: 1)
    case "_":
      controller.adjustFontSize(by: -1)
    default:
      return false
    }
    return true
  }

  func runAction(_ id: NoteAction.Kind) {
    dismissOverlay()
    switch id {
    case .browseNotes:
      presentSwitcher()
    case .findInNote:
      showFindBar()
    case .exportNote:
      exportCurrentNote()
    case .moveListItemUp:
      moveListItem(by: -1)
    case .moveListItemDown:
      moveListItem(by: 1)
    case .format:
      presentFormatBar()
    default:
      runControllerAction(id)
    }
  }

  /// The ⌘K actions that only need the controller.
  private func runControllerAction(_ id: NoteAction.Kind) {
    switch id {
    case .newNote:
      controller.createNote()
    case .duplicateNote:
      controller.duplicateCurrentNote()
    case .copyNote:
      controller.copyCurrentNote()
    case .copyDeepLink:
      controller.copyDeepLink()
    case .zoomIn:
      controller.adjustFontSize(by: 1)
    case .zoomOut:
      controller.adjustFontSize(by: -1)
    case .resetZoom:
      controller.resetFontSize()
    case .deleteNote:
      controller.deleteCurrentNote()
    default:
      break
    }
  }

  /// ⇧⌘P pins the switcher's selected note while the switcher is open, otherwise the current note.
  private func togglePinFromKeyboard() {
    if overlayKind == .switcher {
      switcherModel.pinSelection()
    } else if let id = controller.currentNoteID {
      controller.togglePin(id)
    }
  }

  /// ⌃X deletes the switcher's selected note while the switcher is open, otherwise the current note.
  private func deleteFromKeyboard() {
    if overlayKind == .switcher {
      switcherModel.deleteSelection()
    } else {
      runAction(.deleteNote)
    }
  }

  /// ⌘1–9 opens the nth pinned note, in the switcher's Pinned order.
  private func openPinnedNote(at index: Int) -> Bool {
    let pinned = controller.orderedNotes().filter { controller.pinnedIDs.contains($0.id) }
    guard pinned.indices.contains(index) else {
      return false
    }
    controller.openFromSwitcher(pinned[index].id)
    dismissOverlay()
    return true
  }

  func showFindBar() {
    performFindAction(.showFindInterface)
  }

  private func performFindAction(_ action: NSTextFinder.Action) {
    let sender = NSMenuItem()
    sender.tag = action.rawValue
    textView.performTextFinderAction(sender)
  }

  /// ⌘K, ⌘P and the format toggle close their own overlay instead of rebuilding it.
  private func toggleOverlay(_ kind: OverlayKind, present: () -> Void) {
    if overlayKind == kind {
      dismissOverlay()
    } else {
      present()
    }
  }

  @objc
  func toggleFormatBar() {
    toggleOverlay(.format, present: presentFormatBar)
  }
}

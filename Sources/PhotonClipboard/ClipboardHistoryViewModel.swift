#if canImport(AppKit)
import AppKit
import Combine
import Foundation
import PhotonCore

/// State for the clipboard view inside the launcher panel: query, ranked
/// results, selection, and the entry actions. The launcher forwards its
/// search text into `query` and key events into `handleKeyDown`.
@MainActor
public final class ClipboardHistoryViewModel: ObservableObject {
  public struct Notice: Equatable, Sendable {
    public let message: String
    public let offersAccessibility: Bool
  }

  @Published public var query = "" {
    didSet {
      if query != oldValue {
        notice = nil
        refilter()
        // A new query always starts on the top row, even if the old selection still matches.
        selectedID = results.first?.id
      }
    }
  }

  @Published public private(set) var results: [ClipboardItem] = []
  @Published public var selectedID: UUID? {
    didSet {
      if selectedID != oldValue {
        selectionEpoch &+= 1
      }
    }
  }

  /// Increments whenever the selected row changes so SwiftUI list rows redraw.
  @Published public private(set) var selectionEpoch = 0
  @Published public private(set) var notice: Notice?
  @Published public private(set) var isConfirmingClear = false

  public let manager: ClipboardManager

  /// Asks the host to close the panel (after a paste or copy).
  public var onDismiss: (() -> Void)?

  private var subscriptions: Set<AnyCancellable> = []
  private var hasPromptedForAccessibility = false

  public init(manager: ClipboardManager) {
    self.manager = manager
    manager.$items
      .sink { [weak self] items in
        self?.refilter(items: items)
      }
      .store(in: &subscriptions)
    refilter()
  }

  /// Called every time the launcher enters clipboard mode.
  public func reset() {
    notice = nil
    isConfirmingClear = false
    manager.refreshAccessibility()
    if query.isEmpty {
      refilter()
    } else {
      query = ""
    }
    selectedID = results.first?.id
  }

  public var selectedItem: ClipboardItem? {
    guard let selectedID else {
      return nil
    }
    return results.first { $0.id == selectedID }
  }

  public var selectedIndex: Int? {
    guard let selectedID else {
      return nil
    }
    return results.firstIndex { $0.id == selectedID }
  }

  /// One-line empty state when history is off, history is empty, or a filter has no matches.
  public var showsCompactEmptyRow: Bool {
    !manager.isEnabled || manager.items.isEmpty || !query.isEmpty
  }

  public var compactEmptyMessage: String {
    if !manager.isEnabled {
      return "Clipboard history is off. Turn it on in Settings \u{203A} Clipboard."
    }
    if manager.items.isEmpty {
      return "Copy something in any app to see it here"
    }
    return "No matches"
  }

  public func moveSelection(_ delta: Int) {
    guard !results.isEmpty else {
      return
    }
    let next = SelectionNavigation.moving(from: selectedIndex ?? 0, by: delta, count: results.count)
    selectedID = results[next].id
  }

  public func selectFirst() {
    selectedID = results.first?.id
  }

  public func selectLast() {
    selectedID = results.last?.id
  }

  // MARK: Keyboard

  /// Returns `true` when the event was consumed. Return confirms a pending clear-all or runs
  /// the primary action. Cmd+Return arrives here only from keypad Enter (keyCode 76), because the
  /// launcher's Cmd+Return action matches keyCode 36. Esc is only consumed while a clear-all
  /// confirmation is pending; the host decides what Esc means otherwise. Up/Down stay with the
  /// launcher so the compact bar can expand before the selection moves. The other entry
  /// shortcuts are launcher actions.
  public func handleKeyDown(_ event: NSEvent) -> Bool {
    switch event.keyCode {
    case 36, 76:
      if isConfirmingClear {
        confirmClearAll()
      } else if event.modifierFlags.contains(.command) {
        Task { await performSecondaryAction() }
      } else {
        Task { await performPrimaryAction() }
      }
      return true
    case 53 where isConfirmingClear:
      isConfirmingClear = false
      return true
    default:
      return false
    }
  }

  // MARK: Actions

  /// Return: the Settings > Clipboard primary action on the selection.
  public func performPrimaryAction() async {
    await perform(manager.settings.pasteBehavior)
  }

  /// Cmd+Return: whichever of paste and copy is not the primary action.
  public func performSecondaryAction() async {
    await perform(manager.settings.pasteBehavior.other)
  }

  /// Selects `item` and runs `behavior` on it. Used by double-click and the row context menu.
  public func perform(_ behavior: ClipboardPasteBehavior, on item: ClipboardItem) {
    selectedID = item.id
    Task { await perform(behavior) }
  }

  private func perform(_ behavior: ClipboardPasteBehavior) async {
    guard let item = selectedItem else {
      return
    }
    switch await manager.paste(item, behavior: behavior) {
    case .pasted:
      onDismiss?()
    case .copied:
      onDismiss?()
    case .accessibilityRequired:
      if !hasPromptedForAccessibility {
        hasPromptedForAccessibility = true
        manager.requestAccessibility()
      }
      notice = Notice(
        message: "Copied. Grant Photon Accessibility access to paste directly.",
        offersAccessibility: true
      )
    case .eventInjectionFailed:
      notice = Notice(
        message: "Copied, but Photon could not send Paste. Try again or use Copy to Clipboard.",
        offersAccessibility: false
      )
    }
  }

  public func togglePin(_ item: ClipboardItem) {
    manager.togglePin(id: item.id)
  }

  /// Deletes `item`. The selection moves to the row that takes its place only when `item` was selected.
  public func delete(_ item: ClipboardItem) {
    manager.delete(id: item.id)
    guard let index = results.firstIndex(where: { $0.id == item.id }) else {
      return
    }
    results.remove(at: index)
    if selectedID == item.id {
      selectedID = results.isEmpty ? nil : results[min(index, results.count - 1)].id
    }
  }

  public func requestClearAll() {
    guard !manager.items.isEmpty else {
      return
    }
    isConfirmingClear = true
  }

  public func cancelClearAll() {
    isConfirmingClear = false
  }

  public func confirmClearAll() {
    isConfirmingClear = false
    manager.clearAll()
    results = []
    selectedID = nil
  }

  public func openAccessibilitySettings() {
    manager.openAccessibilitySettings()
  }

  // MARK: Internals

  private func refilter(items: [ClipboardItem]? = nil) {
    let source = items ?? manager.items
    results = ClipboardSearch.rank(source, query: query)
    if let selectedID, results.contains(where: { $0.id == selectedID }) {
      return
    }
    selectedID = results.first?.id
  }
}
#endif

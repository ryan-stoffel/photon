import AppKit
import Combine
import Foundation
import PhotonCore

/// State and behaviour of the launcher's file mode. The launcher feeds it the
/// query and key events; it owns the results, the selection, Quick Look, and
/// the actions.
@MainActor
public final class FileSearchController: ObservableObject {
  public enum Status: Equatable, Sendable {
    case idle
    case searching
    case recents
    case noRecents
    case results
    case empty(String)
    case unavailable
    case needsAccess(String)
  }

  /// Ask the host to make the launcher panel key again (after Quick Look closes).
  public var onRequestFocus: (@MainActor () -> Void)?
  /// Ask the host to hide the launcher (after an action ran).
  public var onRequestDismiss: (@MainActor () -> Void)?
  /// Ask the host to activate the app so an auxiliary panel can take keyboard focus.
  public var onRequestActivation: (@MainActor () -> Void)?
  /// Opens the normal guided folder-selection flow without dismissing Photon.
  public var onRequestAccess: (@MainActor () -> Void)?

  @Published public private(set) var results: [RankedFile] = []
  @Published public private(set) var status: Status = .idle
  @Published public private(set) var isSearching = false
  @Published public private(set) var notice: String?
  @Published public private(set) var accessNotice: String?
  @Published public private(set) var isRequestingAccess = false
  @Published public var selectedID: String? {
    didSet {
      if selectedID != oldValue {
        quickLook.update(selected?.url)
      }
    }
  }

  public var settings: FileSearchSettings
  public let quickLook = QuickLookCoordinator()

  private let engine: FileSearchEngine
  private var query = ""
  private var searchTask: Task<Void, Never>?
  private var noticeTask: Task<Void, Never>?
  /// Query the current `results` belong to. A new query selects the first row, while a
  /// re-run of the same query (after a settings change) keeps the selection.
  private var resultsQuery = ""
  private var protectedResumeQuery: String?
  private var resumeProtectionTask: Task<Void, Never>?

  public var prefersCompactLauncherLayout: Bool {
    false
  }

  public var currentQuery: String {
    query
  }

  public init(settings: FileSearchSettings = FileSearchSettings(), engine: FileSearchEngine = FileSearchEngine()) {
    self.settings = settings
    self.engine = engine
    quickLook.onDidClose = { [weak self] in
      self?.onRequestFocus?()
    }
    quickLook.onMove = { [weak self] delta in
      self?.moveSelection(delta)
    }
  }

  public var selected: FileResult? {
    results.first { $0.id == selectedID }?.file
  }

  /// True while Quick Look or a folder-grant sheet owns focus; the launcher must not hide itself then.
  public var holdsFocus: Bool {
    quickLook.isVisible || isRequestingAccess
  }

  public func beginAccessRequest() {
    isRequestingAccess = true
  }

  public func endAccessRequest() {
    isRequestingAccess = false
  }

  // MARK: - Lifecycle

  public func activate(query: String) {
    update(query: query)
  }

  /// Drops grant-resume protection so the next `deactivate`/`activate` is a
  /// real session, not a replay of the previous Files query.
  public func clearResumeProtection() {
    resumeProtectionTask?.cancel()
    resumeProtectionTask = nil
    protectedResumeQuery = nil
  }

  public func update(query: String) {
    let requested = query.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmed = requested.isEmpty ? protectedResumeQuery ?? requested : requested
    self.query = trimmed
    searchTask?.cancel()
    guard !trimmed.isEmpty else {
      engine.cancel()
      loadRecents()
      return
    }
    isSearching = true
    if results.isEmpty {
      status = .searching
    }
    searchTask = Task { [weak self] in
      await self?.runSearch(trimmed)
    }
  }

  public func update(settings: FileSearchSettings, accessNotice: String? = nil) {
    let changed = self.settings != settings
    self.settings = settings
    self.accessNotice = accessNotice
    if changed, !query.isEmpty {
      update(query: query)
    }
  }

  public func requestFileAccess() {
    onRequestAccess?()
  }

  public func resumeAfterAccess(query: String) {
    resumeProtectionTask?.cancel()
    protectedResumeQuery = query
    update(query: query)
    resumeProtectionTask = Task { [weak self] in
      try? await Task.sleep(for: .seconds(5))
      guard !Task.isCancelled else {
        return
      }
      self?.protectedResumeQuery = nil
    }
  }

  /// Keeps the current list on screen until recents arrive, like a typed search does.
  private func loadRecents() {
    isSearching = true
    if results.isEmpty {
      status = .searching
    }
    resultsQuery = ""
    searchTask = Task { [weak self] in
      guard let self else {
        return
      }
      let response = await engine.recent(settings: settings, limit: settings.clampedMaxResults)
      guard !Task.isCancelled, query.isEmpty else {
        return
      }
      isSearching = false
      results = response?.files ?? []
      status = results.isEmpty ? .noRecents : .recents
      selectedID = results.first?.id
    }
  }

  public func deactivate() {
    if protectedResumeQuery != nil || isRequestingAccess {
      quickLook.hide()
      return
    }
    searchTask?.cancel()
    searchTask = nil
    engine.cancel()
    quickLook.hide()
    noticeTask?.cancel()
    notice = nil
    query = ""
    clearResults()
  }

  private func runSearch(_ query: String) async {
    let request = FileSearchEngine.Request(query: query, settings: settings, limit: settings.clampedMaxResults)
    let response = await engine.search(request)
    guard !Task.isCancelled, query == self.query else {
      return
    }
    isSearching = false
    guard let response else {
      if results.isEmpty {
        status = .empty(query)
      }
      return
    }
    results = response.files
    if !response.spotlightAvailable {
      status = .unavailable
    } else if results.isEmpty {
      if !response.spotlightAvailable, settings.grantedFolders.isEmpty {
        status = .needsAccess(response.query)
      } else {
        status = .empty(response.query)
      }
    } else {
      status = .results
    }
    let sameQuery = query == resultsQuery
    resultsQuery = query
    if sameQuery, let selectedID, results.contains(where: { $0.id == selectedID }) {
      return
    }
    selectedID = results.first?.id
  }

  private func clearResults() {
    results = []
    resultsQuery = ""
    status = .idle
    isSearching = false
    selectedID = nil
  }

  // MARK: - Selection

  /// Moves the selection by `delta` rows, stopping at the first and last rows.
  public func moveSelection(_ delta: Int) {
    guard !results.isEmpty else {
      return
    }
    let index = results.firstIndex { $0.id == selectedID } ?? 0
    selectedID = results[SelectionNavigation.moving(from: index, by: delta, count: results.count)].id
  }

  public func select(_ file: FileResult) {
    selectedID = file.id
  }

  // MARK: - Actions

  /// Runs the default action (Enter). Returns true when the launcher should hide.
  @discardableResult
  public func performPrimaryAction() -> Bool {
    perform(settings.defaultAction)
  }

  /// Runs the other action (Cmd+Enter). Returns true when the launcher should hide.
  @discardableResult
  public func performSecondaryAction() -> Bool {
    perform(settings.defaultAction.other)
  }

  public func copyPath() {
    guard let selected else {
      return
    }
    FileActions.copyPath(selected)
    show(notice: "Path copied")
  }

  public func toggleQuickLook() {
    if quickLook.isVisible {
      quickLook.hide()
    } else if let selected {
      onRequestActivation?()
      quickLook.show(selected.url)
    }
  }

  private func perform(_ action: FileDefaultAction) -> Bool {
    guard let selected else {
      return false
    }
    quickLook.hide()
    do {
      try FileActions.perform(action, on: selected)
      return true
    } catch {
      show(notice: error.localizedDescription)
      return false
    }
  }

  private func show(notice text: String) {
    noticeTask?.cancel()
    notice = text
    noticeTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(1500))
      guard !Task.isCancelled else {
        return
      }
      self?.notice = nil
    }
  }

  // MARK: - Keys

  /// Escape closes Quick Look. Returns true when the event was consumed. Action shortcuts
  /// (⌘↵, ⌘Y, ⌥⌘C) run from the launcher's action list; arrows and Enter stay with the launcher.
  public func handle(_ event: NSEvent) -> Bool {
    guard event.keyCode == 53, quickLook.isVisible else {
      return false
    }
    quickLook.hide()
    return true
  }
}

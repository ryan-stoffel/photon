import Combine
import PhotonClipboard
import PhotonCore
import PhotonFiles
import SwiftUI

/// What the panel shows below the search field. Clipboard is its own session
/// (landed in GH-3). File search uses the `LauncherMode` protocol on top of
/// `.commands`. Unify these later (see the chore issue).
enum LauncherSession: Equatable {
  case commands
  case clipboard
}

@MainActor
final class LauncherViewModel: ObservableObject {
  @Published var query = "" {
    didSet {
      guard query != oldValue else {
        return
      }
      showsActions = false
      switch session {
      case .clipboard:
        clipboard?.query = query
      case .commands:
        if clipboard != nil, activeMode == nil, let sub = ClipboardProvider.historyQuery(fromLauncherQuery: query) {
          enterClipboard(query: sub)
        } else if activeMode == nil, let match = prefixMatch(in: query) {
          enter(mode: match.mode, query: match.remainder)
        } else if let activeMode {
          activeMode.update(query: query)
        } else if query.isEmpty, !preferences.showsSuggestions {
          // Compact mode collapses at once instead of waiting for an empty search.
          revealsRecommendations = false
          clearResults()
        } else {
          Task { await refresh() }
        }
      }
      updateContent()
    }
  }

  @Published var results: [RankedCommand] = [] {
    didSet { updateContent() }
  }

  @Published var selectedID: String? {
    didSet {
      if selectedID != oldValue {
        showsActions = false
      }
    }
  }

  @Published var isLoading = false
  @Published var lastError: String?
  @Published private(set) var focusGeneration = 0
  @Published private(set) var session: LauncherSession = .commands {
    didSet { updateContent() }
  }

  /// The ⌘K action panel. It closes when the query or the selection changes, and on hide.
  @Published var showsActions = false {
    didSet { updateContent() }
  }

  /// Filter text typed into the ⌘K panel.
  @Published var actionQuery = "" {
    didSet { actionSelectedID = nil }
  }

  /// Highlighted ⌘K panel row. Nil means the first filtered action.
  @Published var actionSelectedID: String?

  @Published private(set) var activeMode: (any LauncherMode)? {
    didSet { updateContent() }
  }

  /// Down on the empty compact bar reveals Suggestions, ordered by local use count.
  @Published private(set) var revealsRecommendations = false {
    didSet { updateContent() }
  }

  /// How many leading rows belong to the Suggestions section. Zero hides the header.
  @Published var suggestionCount = 0

  /// True when a typed query matched nothing and the list holds the Search Files fallback instead.
  @Published private(set) var showsFallbacks = false

  /// Drives the panel height; `LauncherPanelController` resizes the window when it changes.
  @Published private(set) var content: LauncherContent = .searchOnly

  /// Settings > Appearance values the launcher reads. Set by the panel controller.
  @Published var preferences = LauncherPreferences(showsSuggestions: false, width: .default) {
    didSet {
      guard preferences != oldValue else {
        return
      }
      let toggledSuggestions = preferences.showsSuggestions != oldValue.showsSuggestions
      if toggledSuggestions, query.isEmpty, showsCommandList {
        if preferences.showsSuggestions {
          revealsRecommendations = false
          Task { await refresh() }
        } else {
          revealsRecommendations = false
          clearResults()
        }
      }
      updateContent()
    }
  }

  let registry: CommandRegistry
  var frecency: FrecencyStore

  /// Set by `AppRuntime` once the clipboard feature is available.
  var clipboard: ClipboardHistoryViewModel? {
    didSet {
      clipboardCancellable = clipboard?.objectWillChange
        .receive(on: RunLoop.main)
        .sink { [weak self] _ in
          guard let self else {
            return
          }
          objectWillChange.send()
          updateContent()
        }
    }
  }

  private var clipboardCancellable: AnyCancellable?
  private(set) var modes: [any LauncherMode] = []
  let limit = 30
  let trailingLimit = 5
  /// Searches finish out of order when typing fast; only the latest one may publish.
  private var searchGeneration = 0
  /// Query behind `results`. A new query moves the selection back to the first row.
  private var resultsQuery = ""

  init(registry: CommandRegistry, frecency: FrecencyStore) {
    self.registry = registry
    self.frecency = frecency
  }

  /// Launcher bar width stays on the Appearance preset. Files and clipboard
  /// detail split list/preview horizontally and grow downward inside that width.
  var panelWidth: Double {
    preferences.width.points
  }

  var rows: [LauncherRow] {
    results.map { LauncherRow(command: $0.command) }
  }

  var suggestionRows: [LauncherRow] {
    guard suggestionCount > 0 else {
      return []
    }
    return Array(rows.prefix(suggestionCount))
  }

  var rowsAfterSuggestions: [LauncherRow] {
    guard suggestionCount > 0 else {
      return rows
    }
    return Array(rows.dropFirst(suggestionCount))
  }

  var selectedRow: LauncherRow? {
    guard let selectedID, let ranked = results.first(where: { $0.id == selectedID }) else {
      return nil
    }
    return LauncherRow(command: ranked.command)
  }

  /// True while the default command list (not a mode or the clipboard) is on screen.
  var showsCommandList: Bool {
    session == .commands && activeMode == nil
  }

  func register(mode: any LauncherMode) {
    modes.removeAll { $0.id == mode.id }
    modes.append(mode)
  }

  func refreshLayout() {
    objectWillChange.send()
    updateContent()
  }

  func requestSearchFocus() {
    focusGeneration &+= 1
  }

  func resetForShow() {
    resetTransientUI()
    selectedID = results.first?.id
    if query.isEmpty, !preferences.showsSuggestions {
      clearResults()
    }
  }

  /// Collapse clipboard/mode chrome before the window is ordered out so the next
  /// open cannot inherit a tall panel around a compact SwiftUI root.
  func resetForHide() {
    resetTransientUI()
  }

  /// Closes any auxiliary UI the active mode owns (Quick Look) without leaving the mode.
  func prepareForHide() {
    activeMode?.deactivate()
  }

  func refresh() async {
    guard showsCommandList else {
      return
    }
    if query.isEmpty, !preferences.showsSuggestions, !revealsRecommendations {
      clearResults()
      return
    }
    searchGeneration += 1
    let generation = searchGeneration
    let started = PhotonTiming.start()
    if results.isEmpty {
      isLoading = true
    }
    let searched = query
    let ranked = await registry.search(searched, frecency: frecency)
    guard showsCommandList, generation == searchGeneration else {
      return
    }
    let arranged = arrange(ranked, forEmptyQuery: searched.isEmpty)
    if suggestionCount != arranged.suggestionCount {
      suggestionCount = arranged.suggestionCount
    }
    let fallback = arranged.commands.isEmpty ? fallbackCommand(for: searched) : nil
    showsFallbacks = fallback != nil
    results = fallback.map { [$0] } ?? arranged.commands
    if searched != resultsQuery || !results.contains(where: { $0.id == selectedID }) {
      selectedID = results.first?.id
    }
    resultsQuery = searched
    isLoading = false
    prefetchIcons(for: results)
    PhotonTiming.end("launcher.search", from: started)
  }

  func moveSelection(_ delta: Int) {
    if session == .clipboard {
      clipboard?.moveSelection(delta)
      return
    }
    if let activeMode {
      activeMode.moveSelection(delta)
      updateContent()
      return
    }
    if showsCommandList, query.isEmpty, results.isEmpty, delta > 0 {
      revealRecommendations()
      Task { await refresh() }
      return
    }
    guard !results.isEmpty else {
      return
    }
    let index = results.firstIndex(where: { $0.id == selectedID }) ?? 0
    let next = SelectionNavigation.moving(from: index, by: delta, count: results.count)
    selectedID = results[next].id
  }

  /// Down on the empty bar lists Suggestions: apps and commands ordered by use count.
  func revealRecommendations() {
    guard showsCommandList, query.isEmpty else {
      return
    }
    revealsRecommendations = true
  }

  /// Runs the selection. Returns true when the launcher should hide.
  func runSelection() async -> Bool {
    if session == .clipboard {
      await clipboard?.performPrimaryAction()
      return false
    }
    if let activeMode {
      return activeMode.performPrimaryAction()
    }
    guard let selectedID, let ranked = results.first(where: { $0.id == selectedID }) else {
      return false
    }
    if ranked.command.id == ClipboardProvider.historyCommandID, clipboard != nil {
      frecency.recordUse(id: ranked.command.id)
      lastError = nil
      enterClipboard(query: "")
      return false
    }
    if let mode = modes.first(where: { $0.activationCommandID == ranked.command.id }) {
      frecency.recordUse(id: ranked.command.id)
      lastError = nil
      // The zero-result fallback carries the typed text into the mode.
      enter(mode: mode, query: showsFallbacks ? query.trimmingCharacters(in: .whitespacesAndNewlines) : "")
      return false
    }
    do {
      try await registry.execute(ranked.command)
      frecency.recordUse(id: ranked.command.id)
      lastError = nil
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  // MARK: Clipboard session

  /// Switches the panel to clipboard history. `query` seeds its search field.
  func enterClipboard(query initialQuery: String) {
    guard let clipboard else {
      return
    }
    exitMode(clearingQuery: false)
    lastError = nil
    session = .clipboard
    clipboard.reset()
    if query != initialQuery {
      query = initialQuery
    } else {
      clipboard.query = initialQuery
    }
    updateContent()
  }

  /// Back to the command list with an empty query.
  func exitClipboard() {
    guard session == .clipboard else {
      return
    }
    session = .commands
    if query.isEmpty {
      Task { await refresh() }
    } else {
      query = ""
    }
  }

  // MARK: Feature modes (file search today)

  func enter(mode: any LauncherMode, query: String) {
    if session == .clipboard {
      session = .commands
    }
    activeMode?.deactivate()
    activeMode = mode
    lastError = nil
    if self.query != query {
      self.query = query
    }
    mode.activate(query: query)
    updateContent()
  }

  func exitMode(clearingQuery: Bool = true) {
    guard let activeMode else {
      return
    }
    activeMode.deactivate()
    self.activeMode = nil
    if clearingQuery {
      query = ""
      Task { await refresh() }
    }
  }

  func mode(forInlineProvider providerID: String) -> (any LauncherMode)? {
    modes.first { $0.inlineProviderID == providerID }
  }

  private func prefixMatch(in query: String) -> (mode: any LauncherMode, remainder: String)? {
    let lowered = query.lowercased()
    for mode in modes {
      for prefix in mode.prefixes where lowered.hasPrefix(prefix.lowercased()) {
        return (mode, String(query.dropFirst(prefix.count)))
      }
    }
    return nil
  }

  private func resetTransientUI() {
    showsActions = false
    revealsRecommendations = false
    if session == .clipboard {
      session = .commands
    }
    exitMode(clearingQuery: false)
    lastError = nil
    if !query.isEmpty {
      query = ""
    } else {
      updateContent()
    }
  }

  private func clearResults() {
    searchGeneration += 1
    isLoading = false
    if !results.isEmpty {
      results = []
    }
    if suggestionCount != 0 {
      suggestionCount = 0
    }
    showsFallbacks = false
    resultsQuery = ""
    selectedID = nil
  }

  /// Search Files, offered when a typed query matches nothing. `runSelection` enters Files with the query.
  private func fallbackCommand(for query: String) -> RankedCommand? {
    guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          let command = (registry.provider(id: "files") as? FilesProvider)?.searchCommand,
          modes.contains(where: { $0.activationCommandID == command.id })
    else {
      return nil
    }
    return RankedCommand(command: command, textScore: 0, frecencyScore: 0)
  }

  private func updateContent() {
    var next: LauncherContent = switch session {
    case .clipboard:
      clipboardContent()
    case .commands:
      if let activeMode {
        if activeMode.prefersCompactLauncherLayout {
          .searchOnly
        } else {
          .fullHeight
        }
      } else if query.isEmpty, !preferences.showsSuggestions, !revealsRecommendations {
        .searchOnly
      } else if query.isEmpty {
        .recommendations
      } else {
        .rows(count: results.count, showsCalculatorHero: calculatorHero != nil)
      }
    }
    // The ⌘K panel needs room, so a compact or short panel grows while it is open.
    if showsActions {
      switch next {
      case .searchOnly, .rows:
        next = showsCommandList ? .recommendations : .fullHeight
      case .recommendations, .fullHeight:
        break
      }
    }
    if next != content {
      content = next
    }
  }

  /// Clipboard history always opens expanded. A filter with no matches keeps the height. History that
  /// is off shows one message line, sized like the zero-result list (no section header).
  private func clipboardContent() -> LauncherContent {
    guard let clipboard else {
      return .searchOnly
    }
    if !clipboard.manager.items.isEmpty {
      return .fullHeight
    }
    if clipboard.showsCompactEmptyRow {
      return .rows(count: 0, showsCalculatorHero: false)
    }
    return .searchOnly
  }

  /// Rows resolve their icon on first draw; this warms the ones below the fold.
  private func prefetchIcons(for ranked: [RankedCommand]) {
    let icons = ranked.compactMap(\.command.icon)
    guard !icons.isEmpty else {
      return
    }
    Task.detached(priority: .utility) {
      CommandIconCache.shared.prefetch(icons)
    }
  }
}

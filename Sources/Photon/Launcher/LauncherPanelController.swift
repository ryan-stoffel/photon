import AppKit
import Combine
import PhotonApps
import PhotonClipboard
import PhotonCore
import PhotonFiles
import QuickLookUI
import SwiftUI

@MainActor
final class LauncherPanelController: NSObject, NSWindowDelegate {
  let settings: SettingsStore
  let runningApps: RunningApplications
  let registry: CommandRegistry
  private let frecencyURL: URL
  let model: LauncherViewModel
  /// Set by `FileSearchIntegration` so main-bar queries can promote into Files mode.
  weak var filesProvider: FilesProvider?
  /// Set by `FileSearchIntegration` for parity hooks and hard resets between Files sessions.
  weak var fileSearchController: FileSearchController?
  var panel: LauncherPanel?
  private var cancellables: Set<AnyCancellable> = []
  let centerGuides = LauncherCenterGuidesOverlay()
  var searchBarDragInitialOrigin: NSPoint?
  var isDraggingLauncher = false
  var chromeMouseDownCount = 0
  var acceptedChromeDragCount = 0
  private var focusTransitionGeneration = 0
  var autoHideSuppressedUntil = Date.distantPast
  /// App that was frontmost before a mode asked us to activate; restored on hide.
  private var previousApplication: NSRunningApplication?
  private var iconRefreshTask: Task<Void, Never>?

  init(settings: SettingsStore, registry: CommandRegistry, frecencyURL: URL, runningApps: RunningApplications) {
    self.settings = settings
    self.runningApps = runningApps
    self.registry = registry
    self.frecencyURL = frecencyURL
    model = LauncherViewModel(registry: registry, frecency: FrecencyStore.load(from: frecencyURL))
    super.init()
    model.preferences = settings.launcherPreferences
    observe()
  }

  /// The window follows the model: `content` decides the height, the width preset the width.
  /// `@Published` emits from `willSet`, so the sinks use the incoming value, never the model's.
  private func observe() {
    model.$content
      .removeDuplicates()
      .sink { [weak self] content in
        guard let self else {
          return
        }
        resize(width: model.panelWidth, content: content)
      }
      .store(in: &cancellables)
    model.$preferences
      .map(\.width)
      .removeDuplicates()
      .sink { [weak self] _ in
        guard let self else {
          return
        }
        resize(width: model.panelWidth, content: model.content)
      }
      .store(in: &cancellables)
    // objectWillChange fires before the write lands; hop once through the run loop to read the new values.
    settings.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak self] _ in
        guard let self else {
          return
        }
        model.preferences = settings.launcherPreferences
      }
      .store(in: &cancellables)
    settings.$launcherStoredPosition
      .removeDuplicates()
      .sink { [weak self] _ in
        guard let self, let panel, panel.isVisible, !isDraggingLauncher else {
          return
        }
        position(panel)
      }
      .store(in: &cancellables)
  }

  func currentFrecency() -> FrecencyStore {
    model.frecency
  }

  var panelWindowForScreenshot: NSWindow? {
    panel
  }

  /// Enables clipboard mode. Call once at startup, before the panel is shown.
  func attachClipboard(_ manager: ClipboardManager) {
    let clipboard = ClipboardHistoryViewModel(manager: manager)
    clipboard.onDismiss = { [weak self] in
      self?.hide()
    }
    manager.onPrepareForPaste = { [weak self] in
      self?.prepareForPasteDelivery()
    }
    manager.onPasteFailure = { [weak self] in
      self?.showClipboard()
    }
    model.clipboard = clipboard
  }

  /// Phase 2 features with their own launcher mode register here once.
  func register(mode: any LauncherMode) {
    mode.attach(host: self)
    model.register(mode: mode)
  }

  /// Re-runs the current search, for providers whose results arrive asynchronously.
  func refreshResults() {
    guard panel?.isVisible == true else {
      return
    }
    Task { await model.refresh() }
  }

  /// Opens the full Files session (split preview, recents, footer) for a main-bar query.
  func promoteFilesMode(query: String) {
    guard panel?.isVisible == true else {
      return
    }
    guard !NativeParityReporter.suppressFilesPromotion else {
      return
    }
    guard model.showsCommandList, model.activeMode == nil else {
      return
    }
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count >= FileSearchSettings.inlineMinimumQueryLength else {
      return
    }
    guard filesProvider?.hasInlineResults(for: trimmed) == true else {
      return
    }
    guard let mode = model.modes.first(where: { $0.id == "files" }) else {
      return
    }
    if let prefetched = filesProvider?.inlineRankedFiles(for: trimmed) {
      fileSearchController?.seedResults(prefetched, query: trimmed)
    }
    model.enter(mode: mode, query: trimmed)
  }

  func preload() {
    if panel == nil {
      panel = makePanel()
    }
  }

  /// Resolves every provider's icons in the background so the first list draws without a stall.
  func warmIcons() {
    CommandIconCache.onImagesLoaded = { [weak self] in
      self?.scheduleIconRefresh()
    }
    let frecency = model.frecency
    Task.detached(priority: .utility) { [registry] in
      let ranked = await registry.search("", frecency: frecency)
      CommandIconCache.shared.prefetch(ranked.compactMap(\.command.icon))
    }
  }

  func toggle() {
    preload()
    guard let panel else {
      return
    }
    if panel.isVisible {
      hide()
    } else {
      show()
    }
  }

  func show() {
    let started = PhotonTiming.start()
    preload()
    guard let panel else {
      return
    }
    model.resetForShow()
    collapseToCompactIfNeeded(force: true)
    position(panel)
    rememberPreviousApplication()
    panel.orderFrontRegardless()
    panel.makeKey()
    model.requestSearchFocus()
    startMonitor()
    PhotonTiming.end("launcher.visible", from: started)
    Task {
      await model.refresh()
      await registry.reloadAll()
      await model.refresh()
      warmIcons()
    }
  }

  /// Opens the panel straight into clipboard history; toggles it closed when
  /// clipboard history is already showing.
  func showClipboard() {
    preload()
    guard let panel, model.clipboard != nil else {
      return
    }
    if panel.isVisible, model.session == .clipboard {
      hide()
      return
    }
    model.resetForShow()
    collapseToCompactIfNeeded(force: true)
    position(panel)
    rememberPreviousApplication()
    panel.orderFrontRegardless()
    panel.makeKey()
    model.requestSearchFocus()
    startMonitor()
    model.enterClipboard(query: "")
  }

  /// Opens Files mode without resetting the command registry (native parity / resume flows).
  func showFilesMode(query: String) {
    preload()
    guard let panel, let mode = model.modes.first(where: { $0.id == "files" }) else {
      return
    }
    filesProvider?.prepareForFullSession()
    fileSearchController?.clearResumeProtection()
    fileSearchController?.deactivate()
    if model.activeMode?.id == mode.id {
      model.activeMode?.deactivate()
    }
    position(panel)
    rememberPreviousApplication()
    panel.orderFrontRegardless()
    panel.makeKey()
    model.requestSearchFocus()
    startMonitor()
    model.enter(mode: mode, query: query)
  }

  func resume(mode: any LauncherMode, query: String) {
    preload()
    guard let panel else {
      return
    }
    focusTransitionGeneration &+= 1
    autoHideSuppressedUntil = Date().addingTimeInterval(5)
    model.enter(mode: mode, query: query)
    panel.orderFrontRegardless()
    panel.makeKey()
    model.requestSearchFocus()
    startMonitor()
  }

  func hide(restorePrevious: Bool = true) {
    model.prepareForHide()
    filesProvider?.prepareForFullSession()
    model.resetForHide()
    collapseToCompactIfNeeded(force: true)
    panel?.orderOut(nil)
    stopMonitor()
    persistFrecency()
    if restorePrevious {
      restorePreviousApplication()
    } else {
      previousApplication = nil
    }
  }

  func windowDidResignKey(_: Notification) {
    // Another of our windows (Quick Look) may be taking key; decide once that has settled.
    let generation = focusTransitionGeneration
    Task { [weak self] in
      guard let self, let panel, panel.isVisible, !panel.isKeyWindow else {
        return
      }
      guard Date() >= autoHideSuppressedUntil, !isDraggingLauncher else {
        return
      }
      guard generation == focusTransitionGeneration else {
        return
      }
      if model.activeMode?.holdsFocus == true {
        return
      }
      hide()
    }
  }

  private func persistFrecency() {
    do {
      try model.frecency.save(to: frecencyURL)
    } catch {
      NSLog("Photon: could not save frecency: \(error)")
    }
  }

  private func scheduleIconRefresh() {
    iconRefreshTask?.cancel()
    iconRefreshTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(16))
      guard !Task.isCancelled else {
        return
      }
      model.refreshLayout()
    }
  }

  private func restorePreviousApplication() {
    guard let previousApplication else {
      return
    }
    self.previousApplication = nil
    if !previousApplication.isTerminated {
      _ = previousApplication.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
  }

  /// Hides the panel and returns key focus to the app that was frontmost before Photon opened.
  private func prepareForPasteDelivery() {
    hide()
    NSApp.hide(nil)
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
  }

  private func rememberPreviousApplication() {
    guard previousApplication == nil,
          let candidate = NSWorkspace.shared.frontmostApplication,
          candidate.processIdentifier != ProcessInfo.processInfo.processIdentifier
    else {
      return
    }
    previousApplication = candidate
  }

  private func makePanel() -> LauncherPanel {
    let layoutSize = LauncherPanelSize(width: model.panelWidth, content: model.content)
    let size = NSSize(width: layoutSize.width, height: layoutSize.height)
    let panel = LauncherPanel(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .floating
    // `.canJoinAllSpaces` and `.moveToActiveSpace` are mutually exclusive; AppKit throws
    // NSInternalInconsistencyException if both are set, which aborts AppRuntime.start().
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.animationBehavior = .none
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = false
    panel.delegate = self
    panel.activeMode = { [weak self] in
      self?.model.activeMode
    }
    panel.mouseDownHandler = { [weak self, weak panel] event in
      guard let self, let panel else {
        return false
      }
      return handlePanelDrag(event, panel: panel)
    }
    panel.installSearchBarDragMonitor()

    let host = NSHostingView(rootView: LauncherView(
      model: model,
      onRun: { [weak self] in
        self?.hide(restorePrevious: false)
      }
    ).environmentObject(settings).environmentObject(runningApps))
    host.safeAreaRegions = []
    let background = PhotonPanelChrome.embed(
      host,
      frame: NSRect(origin: .zero, size: size),
      cornerRadius: LauncherLayout.cornerRadius,
      material: .popover
    )
    panel.contentView = background
    return panel
  }

  /// If a previous session left the `NSPanel` taller than the SwiftUI root, the
  /// hosting view centers the compact bar in a huge material — the clipped overlay
  /// in GH-89. Force-sync the window to compact height on hide and before show.
  func collapseToCompactIfNeeded(force: Bool = false) {
    let content: LauncherContent = force ? .searchOnly : model.content
    resize(width: model.panelWidth, content: content, force: force)
  }

  /// Keeps the top edge fixed so the search field never jumps.
  /// Recentres horizontally only when snapped to center.
  private func resize(width: Double, content: LauncherContent, force: Bool = false) {
    guard let panel else {
      return
    }
    let layoutSize = LauncherPanelSize(width: width, content: content)
    let size = NSSize(width: layoutSize.width, height: layoutSize.height)
    var frame = panel.frame
    guard force || frame.size != size else {
      return
    }
    let keepsCenter = settings.launcherStoredPosition?.isHorizontallyCentered ?? true
    if keepsCenter, !isDraggingLauncher {
      frame.origin.x = frame.midX - size.width / 2
    }
    frame.origin.y = frame.maxY - size.height
    frame.size = size
    panel.setFrame(frame, display: true, animate: false)
    panel.invalidateShadow()
  }
}

extension LauncherPanelController: LauncherModeHost {
  func modeRequestsFocus() {
    guard let panel, panel.isVisible else {
      return
    }
    panel.makeKey()
  }

  func modeRequestsDismiss() {
    hide()
  }

  func modeRequestsActivation() {
    guard !NSApp.isActive else {
      return
    }
    if previousApplication == nil {
      previousApplication = NSWorkspace.shared.frontmostApplication
    }
    NSApp.activate()
  }

  func modeRequestsLayoutUpdate() {
    model.refreshLayout()
  }

  func suppressAutoHide(for interval: TimeInterval) {
    focusTransitionGeneration &+= 1
    autoHideSuppressedUntil = Date().addingTimeInterval(interval)
  }
}

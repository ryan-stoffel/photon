import AppKit
import PhotonCore

extension LauncherPanelController {
  /// Opens clipboard mode for UI screenshots (empty history in isolated data).
  func showClipboardForScreenshot() {
    showForScreenshot(query: "")
    model.enterClipboard(query: "")
  }

  /// Shows the launcher in a fixed position with an optional query (UI screenshot harness).
  func showForScreenshot(query: String) {
    preload()
    guard let panel else {
      return
    }
    panel.title = "Photon Launcher"
    model.resetForShow()
    collapseToCompactIfNeeded()
    UIScenarioWindowLayout.position(panel, size: panel.frame.size)
    panel.orderFrontRegardless()
    panel.makeKey()
    model.requestSearchFocus()
    startMonitor()
    if !query.isEmpty {
      model.query = query
    }
  }

  @MainActor
  func prepareForScreenshot(query: String) async {
    await registry.reloadAll()
    showForScreenshot(query: query)
    await model.refresh()
    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline, model.results.isEmpty {
      try? await Task.sleep(nanoseconds: 100_000_000)
      await model.refresh()
    }
    prefetchVisibleIcons()
    try? await Task.sleep(nanoseconds: 500_000_000)
  }

  func prefetchVisibleIcons() {
    let icons = model.results.compactMap(\.command.icon)
    guard !icons.isEmpty else {
      return
    }
    CommandIconCache.shared.prefetch(icons)
  }
}

import AppKit
import PhotonCore

extension LauncherPanelController {
  /// Starts a window drag from anywhere on the panel. Clicks still reach rows
  /// and buttons because `LauncherPanel` only calls this after drag slop.
  func handlePanelDrag(_: NSEvent, panel: NSPanel) -> Bool {
    chromeMouseDownCount += 1
    acceptedChromeDragCount += 1
    trackLiveDrag(panel: panel)
    return true
  }

  func handleChromeMouseDown(_ event: NSEvent, panel: NSPanel) -> Bool {
    handlePanelDrag(event, panel: panel)
  }

  func visibleFrame(for panel: NSPanel) -> ScreenVisibleFrame {
    visibleFrame(of: panel.screen ?? NSScreen.main ?? NSScreen.screens.first)
  }

  /// Opens on the screen under the mouse, centred horizontally by default.
  /// Uses the stored position when the user has repositioned the panel.
  func position(_ panel: NSPanel) {
    let mouse = NSEvent.mouseLocation
    guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
      ?? NSScreen.main ?? NSScreen.screens.first
    else {
      return
    }
    let visible = visibleFrame(of: screen)
    let size = PanelSize(width: panel.frame.width, height: panel.frame.height)
    let origin = LauncherPosition.origin(
      panelSize: size,
      visible: visible,
      stored: settings.launcherStoredPosition
    )
    panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
  }

  /// Follows `NSEvent.mouseLocation` until the button is released so the panel
  /// cannot fight SwiftUI's view-local drag translation.
  func trackLiveDrag(panel: NSPanel) {
    guard !isDraggingLauncher else {
      return
    }
    isDraggingLauncher = true
    let startMouse = NSEvent.mouseLocation
    let startOrigin = PanelOrigin(x: panel.frame.origin.x, y: panel.frame.origin.y)
    searchBarDragInitialOrigin = panel.frame.origin
    showCenterGuides(for: panel)

    while true {
      let event = panel.nextEvent(
        matching: [.leftMouseDragged, .leftMouseUp],
        until: Date.distantFuture,
        inMode: .eventTracking,
        dequeue: true
      )
      applyLiveDragOrigin(
        panel: panel,
        startOrigin: startOrigin,
        startMouse: startMouse,
        currentMouse: NSEvent.mouseLocation
      )
      if event == nil || event?.type == .leftMouseUp {
        break
      }
    }

    finishLiveDrag(panel: panel)
  }

  func showCenterGuides(for panel: NSPanel) {
    let visible = visibleFrame(for: panel)
    let guides = LauncherPosition.snapGuideXPositions(
      visible: visible,
      panelWidth: panel.frame.width
    )
    let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first
    if let screen {
      centerGuides.show(
        visibleFrame: screen.visibleFrame,
        guideXLeft: guides.left,
        guideXRight: guides.right
      )
    }
  }

  func applyLiveDragOrigin(
    panel: NSPanel,
    startOrigin: PanelOrigin,
    startMouse: NSPoint,
    currentMouse: NSPoint
  ) {
    let visible = visibleFrame(for: panel)
    let size = PanelSize(width: panel.frame.width, height: panel.frame.height)
    var origin = LauncherPosition.liveDragOrigin(
      initialOrigin: startOrigin,
      startMouse: PanelOrigin(x: startMouse.x, y: startMouse.y),
      currentMouse: PanelOrigin(x: currentMouse.x, y: currentMouse.y),
      panelWidth: size.width,
      visible: visible
    )
    origin = LauncherPosition.clampedOrigin(origin, panelSize: size, visible: visible)
    panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
  }

  func finishLiveDrag(panel: NSPanel) {
    centerGuides.hide()
    let size = PanelSize(width: panel.frame.width, height: panel.frame.height)
    let visible = visibleFrame(for: panel)
    let stored = LauncherPosition.storedPosition(
      origin: PanelOrigin(x: panel.frame.origin.x, y: panel.frame.origin.y),
      panelSize: size,
      visible: visible
    )
    settings.launcherStoredPosition = stored
    let origin = LauncherPosition.origin(panelSize: size, visible: visible, stored: stored)
    panel.setFrameOrigin(NSPoint(x: origin.x, y: origin.y))
    searchBarDragInitialOrigin = nil
    isDraggingLauncher = false
  }

  private func visibleFrame(of screen: NSScreen?) -> ScreenVisibleFrame {
    let rect = screen?.visibleFrame ?? .zero
    return ScreenVisibleFrame(minX: rect.minX, minY: rect.minY, width: rect.width, height: rect.height)
  }
}

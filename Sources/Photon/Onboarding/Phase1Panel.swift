import AppKit
import SwiftUI

final class Phase1Panel: NSPanel {
  static let identifier = NSUserInterfaceItemIdentifier("photon.phase1")

  static func make(model: Phase1Model) -> Phase1Panel {
    let frame = NSScreen.main?.frame ?? Phase1Metrics.fallbackFrame
    let panel = Phase1Panel(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    panel.title = ""
    panel.identifier = identifier
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = false
    panel.isMovable = false
    panel.isRestorable = false
    panel.level = Phase1Metrics.windowLevel
    // Transient and stationary stay out of Mission Control. ignoresCycle stays out of ⌘`.
    panel.collectionBehavior = Phase1Metrics.collectionBehavior
    panel.hidesOnDeactivate = false
    panel.isReleasedWhenClosed = false
    panel.isExcludedFromWindowsMenu = true
    panel.ignoresMouseEvents = false
    let host = Phase1HostingView(rootView: Phase1OverlayView(model: model))
    host.safeAreaRegions = []
    host.frame = NSRect(origin: .zero, size: frame.size)
    host.autoresizingMask = [.width, .height]
    panel.contentView = host
    if let screen = NSScreen.main {
      panel.setFrame(screen.frame, display: false)
    }
    return panel
  }

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }
}

/// NSHostingView is opaque unless told otherwise, which would hide the desktop.
final class Phase1HostingView<Content: View>: NSHostingView<Content> {
  override var isOpaque: Bool {
    false
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    wantsLayer = true
    layer?.isOpaque = false
    layer?.backgroundColor = NSColor.clear.cgColor
  }
}

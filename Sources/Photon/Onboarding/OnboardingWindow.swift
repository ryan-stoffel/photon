import AppKit
import SwiftUI

enum OnboardingChrome {
  static let identifier = NSUserInterfaceItemIdentifier("photon.onboarding")

  @MainActor
  static func screenFrame() -> NSRect {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
    return screen?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
  }

  @MainActor
  static func makeWindow(host: NSHostingView<OnboardingView>) -> OnboardingWindow {
    let frame = screenFrame()
    host.safeAreaRegions = []
    host.frame = NSRect(origin: .zero, size: frame.size)
    host.autoresizingMask = [.width, .height]
    let window = OnboardingWindow(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.title = ""
    window.identifier = identifier
    window.isOpaque = true
    window.backgroundColor = NSColor(srgbRed: 0.012, green: 0.016, blue: 0.03, alpha: 1)
    window.hasShadow = false
    window.isMovable = false
    window.level = .statusBar
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
    window.hidesOnDeactivate = false
    window.isReleasedWhenClosed = false
    window.contentView = host
    return window
  }
}

final class OnboardingWindow: NSWindow {
  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }
}

final class OnboardingOverlayWindow: NSWindow {
  override var canBecomeKey: Bool {
    false
  }

  override var canBecomeMain: Bool {
    false
  }
}

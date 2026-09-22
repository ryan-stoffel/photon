import AppKit
import SwiftUI

enum OnboardingChrome {
  static let identifier = NSUserInterfaceItemIdentifier("photon.onboarding")
  static let size = NSSize(width: 800, height: 560)
  static let cornerRadius: CGFloat = 16

  /// Centered on the screen under the pointer.
  @MainActor
  static func windowFrame() -> NSRect {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
    let bounds = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    return NSRect(
      x: (bounds.midX - size.width / 2).rounded(),
      y: (bounds.midY - size.height / 2).rounded(),
      width: size.width,
      height: size.height
    )
  }

  /// A borderless, non-resizable window. The content is clipped to continuous
  /// 16 pt corners and macOS shapes the soft shadow from that opaque region.
  @MainActor
  static func makeWindow(host: NSHostingView<OnboardingView>) -> OnboardingWindow {
    let frame = windowFrame()
    let bounds = NSRect(origin: .zero, size: frame.size)
    host.safeAreaRegions = []
    host.frame = bounds
    host.autoresizingMask = [.width, .height]

    let clip = NSView(frame: bounds)
    clip.wantsLayer = true
    clip.layer?.cornerRadius = cornerRadius
    clip.layer?.cornerCurve = .continuous
    clip.layer?.masksToBounds = true
    clip.layer?.backgroundColor = NSColor.black.cgColor
    clip.addSubview(host)

    let window = OnboardingWindow(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.title = ""
    window.identifier = identifier
    window.appearance = NSAppearance(named: .darkAqua)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.isMovable = true
    window.isMovableByWindowBackground = true
    window.minSize = size
    window.maxSize = size
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.hidesOnDeactivate = false
    window.isReleasedWhenClosed = false
    window.animationBehavior = .none
    window.contentView = clip
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

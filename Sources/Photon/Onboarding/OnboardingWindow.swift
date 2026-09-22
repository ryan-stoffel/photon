import AppKit
import SwiftUI

enum OnboardingChrome {
  static let identifier = NSUserInterfaceItemIdentifier("photon.onboarding")
  static let size = NSSize(width: 800, height: 560)
  static let cornerRadius: CGFloat = 16

  @MainActor
  static func windowFrame() -> NSRect {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) }
      ?? NSScreen.main
      ?? NSScreen.screens.first
    let bounds = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    return NSRect(
      x: bounds.midX - size.width / 2,
      y: bounds.midY - size.height / 2,
      width: size.width,
      height: size.height
    )
  }

  @MainActor
  static func makeWindow(host: NSHostingView<OnboardingView>) -> OnboardingWindow {
    let frame = windowFrame()
    host.safeAreaRegions = []
    host.frame = NSRect(origin: .zero, size: frame.size)
    host.autoresizingMask = [.width, .height]

    let clip = NSView(frame: NSRect(origin: .zero, size: frame.size))
    clip.wantsLayer = true
    clip.layer?.cornerRadius = cornerRadius
    clip.layer?.masksToBounds = true
    clip.layer?.backgroundColor = NSColor.black.cgColor
    clip.addSubview(host)

    let root = NSView(frame: NSRect(origin: .zero, size: frame.size))
    root.wantsLayer = true
    root.layer?.masksToBounds = false
    root.layer?.backgroundColor = NSColor.clear.cgColor
    root.layer?.shadowColor = NSColor.black.cgColor
    root.layer?.shadowOpacity = 0.42
    root.layer?.shadowRadius = 32
    root.layer?.shadowOffset = CGSize(width: 0, height: -12)
    root.layer?.shadowPath = CGPath(
      roundedRect: root.bounds,
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    )
    root.addSubview(clip)

    let window = OnboardingWindow(
      contentRect: frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    window.title = ""
    window.identifier = identifier
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = false
    window.isMovable = true
    window.isMovableByWindowBackground = true
    window.minSize = size
    window.maxSize = size
    window.level = .statusBar
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.hidesOnDeactivate = false
    window.isReleasedWhenClosed = false
    window.contentView = root
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

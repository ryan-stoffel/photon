import AppKit

/// Notes window chrome: HUD vibrancy, which maps to Liquid Glass on macOS 26+.
enum NotesChrome {
  static func apply(to effectView: NSVisualEffectView, cornerRadius: CGFloat) {
    effectView.material = .hudWindow
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    effectView.wantsLayer = true
    effectView.layer?.cornerRadius = cornerRadius
    effectView.layer?.cornerCurve = .continuous
    effectView.layer?.masksToBounds = true
  }
}

import AppKit

/// ⌘, opens Settings whenever Photon receives key events, including a key launcher panel.
@MainActor
final class SettingsShortcutMonitor {
  static let commaKeyCode: UInt16 = 43

  private var localMonitor: Any?
  private let handler: () -> Void

  init(handler: @escaping () -> Void) {
    self.handler = handler
    localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self, Self.isSettingsShortcut(event) else {
        return event
      }
      self.handler()
      return nil
    }
  }

  func stop() {
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
      self.localMonitor = nil
    }
  }

  static func isSettingsShortcut(_ event: NSEvent) -> Bool {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard flags.contains(.command),
          !flags.contains(.option),
          !flags.contains(.control),
          !flags.contains(.shift)
    else {
      return false
    }
    if event.keyCode == commaKeyCode {
      return true
    }
    return event.charactersIgnoringModifiers == ","
  }
}

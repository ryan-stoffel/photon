import AppKit
import Carbon
import SwiftUI

/// Visible copy for the first-run note. The parity harness matches `step`.
enum WelcomeCopy {
  static let step = "Welcome"
  static let settingsLine = "Settings are in the menu bar menu. ⌘, opens them too."

  static func openLine(hotkey: String) -> String {
    "Open Photon with \(hotkey)."
  }
}

struct WelcomeView: View {
  let hotkey: String
  let onContinue: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(WelcomeCopy.step)
        .font(.title3.weight(.semibold))
      Text(WelcomeCopy.openLine(hotkey: hotkey))
      Text(WelcomeCopy.settingsLine)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        Spacer()
        Button("Continue", action: onContinue)
          .keyboardShortcut(.defaultAction)
      }
    }
    .padding(20)
    .frame(width: WelcomeWindow.contentWidth, alignment: .leading)
  }
}

/// Small titled window. No veil, beam, or space chrome.
final class WelcomeWindow: NSWindow {
  static let identifier = NSUserInterfaceItemIdentifier("photon.welcome")
  static let contentWidth: CGFloat = 400
  static let contentHeight: CGFloat = 196

  var onDismiss: (() -> Void)?

  static func make(hotkey: String) -> WelcomeWindow {
    let size = NSSize(width: contentWidth, height: contentHeight)
    let window = WelcomeWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = WelcomeCopy.step
    window.identifier = identifier
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.level = .normal
    window.isOpaque = true
    window.backgroundColor = .windowBackgroundColor
    window.hasShadow = true
    let host = NSHostingView(rootView: WelcomeView(hotkey: hotkey) { [weak window] in
      window?.onDismiss?()
    })
    host.safeAreaRegions = []
    host.frame = NSRect(origin: .zero, size: size)
    window.contentView = host
    window.setContentSize(size)
    window.center()
    return window
  }

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }

  override func cancelOperation(_ sender: Any?) {
    onDismiss?()
  }

  override func keyDown(with event: NSEvent) {
    if Self.dismisses(event.keyCode) {
      onDismiss?()
      return
    }
    super.keyDown(with: event)
  }

  fileprivate static func dismisses(_ keyCode: UInt16) -> Bool {
    keyCode == UInt16(kVK_Escape)
      || keyCode == UInt16(kVK_Return)
      || keyCode == UInt16(kVK_ANSI_KeypadEnter)
  }
}

@MainActor
final class WelcomeController {
  var onFinish: (() -> Void)?

  private var window: WelcomeWindow?
  private var closeDelegate: WelcomeCloseDelegate?
  private var keyMonitor: Any?
  private var finished = false

  var isVisible: Bool {
    window?.isVisible == true
  }

  var windowNumber: Int {
    guard isVisible, let window else {
      return 0
    }
    return window.windowNumber
  }

  var windowTitle: String {
    window?.title ?? ""
  }

  func present(hotkey: String) {
    finished = false
    tearDown()
    let window = WelcomeWindow.make(hotkey: hotkey)
    let box = WelcomeBox(self)
    let closeDelegate = WelcomeCloseDelegate()
    closeDelegate.onClose = {
      MainActor.assumeIsolated {
        box.value?.dismiss()
      }
    }
    window.onDismiss = {
      MainActor.assumeIsolated {
        box.value?.dismiss()
      }
    }
    window.delegate = closeDelegate
    self.window = window
    self.closeDelegate = closeDelegate
    installKeyMonitor()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func dismiss() {
    guard !finished else {
      return
    }
    finished = true
    tearDown()
    let finish = onFinish
    onFinish = nil
    finish?()
  }

  private func tearDown() {
    removeKeyMonitor()
    window?.delegate = nil
    window?.orderOut(nil)
    window?.contentView = nil
    window = nil
    closeDelegate = nil
  }

  private func installKeyMonitor() {
    removeKeyMonitor()
    let box = WelcomeBox(self)
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let keyCode = event.keyCode
      let windowNumber = event.window?.windowNumber ?? 0
      let handled = MainActor.assumeIsolated {
        box.value?.handleKey(keyCode: keyCode, windowNumber: windowNumber) ?? false
      }
      return handled ? nil : event
    }
  }

  private func removeKeyMonitor() {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
    }
    keyMonitor = nil
  }

  private func handleKey(keyCode: UInt16, windowNumber: Int) -> Bool {
    guard windowNumber == window?.windowNumber, isVisible, WelcomeWindow.dismisses(keyCode) else {
      return false
    }
    dismiss()
    return true
  }
}

private final class WelcomeCloseDelegate: NSObject, NSWindowDelegate {
  var onClose: (() -> Void)?

  func windowShouldClose(_: NSWindow) -> Bool {
    onClose?()
    return false
  }
}

private struct WelcomeBox: @unchecked Sendable {
  weak var value: WelcomeController?

  init(_ value: WelcomeController) {
    self.value = value
  }
}

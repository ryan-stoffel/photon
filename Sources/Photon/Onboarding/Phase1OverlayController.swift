import AppKit
import Carbon
import QuartzCore

@MainActor
final class Phase1OverlayController {
  var onFinish: (() -> Void)?

  private var panel: Phase1Panel?
  private var model: Phase1Model?
  private var keyMonitor: Any?
  private var mouseMonitor: Any?
  private var generation = 0
  private var isDismissing = false

  var isVisible: Bool {
    panel?.isVisible == true
  }

  var isResting: Bool {
    guard isVisible, let model else {
      return false
    }
    return model.isResting()
  }

  var windowNumber: Int {
    guard isVisible, let panel else {
      return 0
    }
    return panel.windowNumber
  }

  func present(settled: Bool) {
    generation += 1
    tearDownPanel()
    let model = Phase1Model(
      settled: settled,
      reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    )
    self.model = model
    let panel = Phase1Panel.make(model: model)
    panel.alphaValue = 1
    self.panel = panel
    let pin = Phase1Space.requestedDesktop != nil
    if pin {
      panel.alphaValue = 0
      panel.ignoresMouseEvents = true
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    panel.orderFrontRegardless()
    if pin {
      guard Phase1Space.pin(panel) else {
        panel.orderOut(nil)
        self.panel = nil
        self.model = nil
        return
      }
      panel.ignoresMouseEvents = false
      panel.alphaValue = 1
    }
    installMonitors()
    if !pin {
      panel.makeKey()
    }
  }

  /// Phase 2 is not this screen. Dismiss the overlay and stop.
  func advanceToPhase2() {
    guard let panel, panel.isVisible, !isDismissing else {
      return
    }
    isDismissing = true
    let token = generation
    let box = Phase1Box(self)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Phase1Metrics.dismissFade
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 0
    } completionHandler: {
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          box.value?.completeDismiss(token: token)
        }
      }
    }
    let fallback = DispatchWorkItem {
      MainActor.assumeIsolated {
        box.value?.completeDismiss(token: token)
      }
    }
    DispatchQueue.main.asyncAfter(
      deadline: .now() + Phase1Metrics.dismissFade + Phase1Metrics.dismissFallbackDelay,
      execute: fallback
    )
  }

  private func completeDismiss(token: Int) {
    guard generation == token, panel != nil || isDismissing else {
      return
    }
    tearDownPanel()
    let finish = onFinish
    onFinish = nil
    finish?()
  }

  private func tearDownPanel() {
    removeMonitors()
    panel?.orderOut(nil)
    panel = nil
    model = nil
    isDismissing = false
  }

  private func installMonitors() {
    removeMonitors()
    let box = Phase1Box(self)
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let keyCode = event.keyCode
      let handled = MainActor.assumeIsolated {
        box.value?.handleKey(keyCode: keyCode) ?? false
      }
      return handled ? nil : event
    }
    mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
      let windowNumber = event.windowNumber
      let handled = MainActor.assumeIsolated {
        box.value?.handleClick(windowNumber: windowNumber) ?? false
      }
      return handled ? nil : event
    }
  }

  private func removeMonitors() {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
    }
    if let mouseMonitor {
      NSEvent.removeMonitor(mouseMonitor)
    }
    keyMonitor = nil
    mouseMonitor = nil
  }

  private func handleKey(keyCode: UInt16) -> Bool {
    let isReturn = keyCode == UInt16(kVK_Return) || keyCode == UInt16(kVK_ANSI_KeypadEnter)
    guard isReturn, isResting, !isDismissing else {
      return false
    }
    advanceToPhase2()
    return true
  }

  private func handleClick(windowNumber: Int) -> Bool {
    guard windowNumber == panel?.windowNumber, isResting, !isDismissing else {
      return false
    }
    advanceToPhase2()
    return true
  }
}

private struct Phase1Box: @unchecked Sendable {
  weak var value: Phase1OverlayController?

  init(_ value: Phase1OverlayController) {
    self.value = value
  }
}

import AppKit
import Carbon
import PhotonKeybinds
import SwiftUI

@MainActor
final class OnboardingController: ObservableObject {
  @Published var step: OnboardingStep = .reveal
  @Published var hotkey: HotkeyCombo
  @Published var permissionNotice: String?
  @Published var permissionWaiting = false
  @Published private(set) var revealStarted = Date()

  var onFinish: (() -> Void)?
  var onPermissionResolved: (() -> Void)?

  private var window: OnboardingWindow?
  private var confettiWindow: NSWindow?
  private var keyMonitor: Any?
  private var schedule: Task<Void, Never>?
  private var permissionSession: OnboardingPermissionSession?
  private var finished = false
  private var celebrated = false
  private var permissionSettled = false

  init(hotkey: HotkeyCombo) {
    self.hotkey = hotkey
  }

  var instant: Bool {
    NativeParityReporter.isRequested
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  var windowNumber: Int {
    window?.windowNumber ?? 0
  }

  var isWaitingForLauncher: Bool {
    isVisible && step == .tryIt && !celebrated && !finished
  }

  func present(hotkey: HotkeyCombo) {
    self.hotkey = hotkey
    finished = false
    celebrated = false
    permissionSettled = false
    permissionNotice = nil
    permissionWaiting = false
    revealStarted = Date()
    step = .reveal
    if window == nil {
      let host = NSHostingView(rootView: OnboardingView(model: self))
      window = OnboardingChrome.makeWindow(host: host)
    }
    if let window {
      window.alphaValue = 1
      window.level = .statusBar
      window.setFrame(OnboardingChrome.screenFrame(), display: true)
    }
    installKeyMonitor()
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    armAutoAdvance()
  }

  func advance() {
    let pending = schedule
    schedule = nil
    pending?.cancel()
    cancelPermissionWatch()
    if step.isPermission {
      onPermissionResolved?()
    }
    permissionNotice = nil
    permissionWaiting = false
    permissionSettled = false
    guard let next = step.next else {
      finish()
      return
    }
    if instant {
      step = next
    } else {
      withAnimation(.easeInOut(duration: OnboardingTiming.content)) {
        step = next
      }
    }
    armAutoAdvance()
  }

  func advanceFromPointer() {
    switch step {
    case .reveal, .feature:
      advance()
    case .permission, .tryIt:
      break
    }
  }

  func grantPermission() {
    guard case let .permission(kind) = step, !permissionSettled, !instant else {
      return
    }
    permissionWaiting = true
    window?.level = .normal
    window?.orderBack(nil)
    let session = OnboardingPermissionSession()
    session.onResolve = { @MainActor [weak self] granted in
      self?.resolvePermission(granted: granted)
    }
    permissionSession = session
    session.start(
      request: { Self.request(kind) },
      isGranted: { Self.isGranted(kind) }
    )
  }

  func skipPermission() {
    guard case let .permission(kind) = step, !permissionSettled else {
      return
    }
    permissionSettled = true
    cancelPermissionWatch()
    permissionWaiting = false
    if instant {
      advance()
      return
    }
    permissionNotice = kind.withheld
    scheduleAdvance(after: OnboardingTiming.permissionNotice)
  }

  func noteLauncherOpened(visible: Bool, frame: NSRect) {
    guard isWaitingForLauncher, visible, frame.width > 1 else {
      return
    }
    celebrated = true
    let pending = schedule
    schedule = nil
    pending?.cancel()
    removeKeyMonitor()
    window?.animator().alphaValue = 0
    let screenFrame = frame
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(OnboardingTiming.content))
      self.window?.orderOut(nil)
      self.window?.alphaValue = 1
      self.playConfetti(around: screenFrame)
    }
  }

  func finish() {
    guard !finished else {
      return
    }
    finished = true
    let pending = schedule
    schedule = nil
    pending?.cancel()
    cancelPermissionWatch()
    removeKeyMonitor()
    FirstLaunch.markInteractiveOnboardingComplete()
    window?.orderOut(nil)
    confettiWindow?.orderOut(nil)
    let callback = onFinish
    onFinish = nil
    callback?()
  }

  func handle(keyCode: UInt16, modifiers _: UInt32) -> Bool {
    if keyCode == UInt16(kVK_Escape) {
      return consumeEscape()
    }
    if isReturn(keyCode), step.isPermission {
      grantPermission()
      return true
    }
    if isAdvanceKey(keyCode), step == .reveal || isFeature {
      advance()
      return true
    }
    return false
  }

  private var isFeature: Bool {
    if case .feature = step {
      return true
    }
    return false
  }

  private func consumeEscape() -> Bool {
    if step.isPermission {
      return true
    }
    advance()
    return true
  }

  private func isReturn(_ keyCode: UInt16) -> Bool {
    keyCode == UInt16(kVK_Return) || keyCode == UInt16(kVK_ANSI_KeypadEnter)
  }

  private func isAdvanceKey(_ keyCode: UInt16) -> Bool {
    isReturn(keyCode) || keyCode == UInt16(kVK_Space) || keyCode == UInt16(kVK_RightArrow)
  }

  private func resolvePermission(granted: Bool) {
    guard !permissionSettled, case let .permission(kind) = step else {
      return
    }
    permissionSettled = true
    permissionWaiting = false
    window?.level = .statusBar
    window?.orderFrontRegardless()
    if granted {
      advance()
      return
    }
    permissionNotice = kind.withheld
    scheduleAdvance(after: OnboardingTiming.permissionNotice)
  }

  private func armAutoAdvance() {
    switch step {
    case .reveal:
      let delay = OnboardingTiming.revealDuration(reduceMotion: reduceMotion)
      scheduleAdvance(after: delay)
    case .feature:
      scheduleAdvance(after: OnboardingTiming.featureHold)
    case .permission, .tryIt:
      break
    }
  }

  private func scheduleAdvance(after seconds: TimeInterval) {
    let pending = schedule
    schedule = nil
    pending?.cancel()
    guard !instant else {
      return
    }
    schedule = Task { @MainActor in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else {
        return
      }
      advance()
    }
  }

  private var reduceMotion: Bool {
    NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
  }

  private static func request(_ kind: OnboardingPermission) -> Bool {
    switch kind {
    case .accessibility:
      AccessibilityPermission.requestTrust()
    case .inputMonitoring:
      AccessibilityPermission.requestInputMonitoring()
    }
  }

  private static func isGranted(_ kind: OnboardingPermission) -> Bool {
    switch kind {
    case .accessibility:
      AccessibilityPermission.isTrusted
    case .inputMonitoring:
      AccessibilityPermission.hasInputMonitoring
    }
  }

  private func playConfetti(around frame: NSRect) {
    let pad: CGFloat = 96
    let rect = frame.insetBy(dx: -pad, dy: -pad)
    let host = NSHostingView(
      rootView: OnboardingConfettiView(started: Date(), reduceMotion: reduceMotion)
    )
    host.frame = NSRect(origin: .zero, size: rect.size)
    let overlay = OnboardingOverlayWindow(
      contentRect: rect,
      styleMask: [.borderless],
      backing: .buffered,
      defer: false
    )
    overlay.isOpaque = false
    overlay.backgroundColor = .clear
    overlay.hasShadow = false
    overlay.ignoresMouseEvents = true
    overlay.level = .statusBar
    overlay.contentView = host
    overlay.orderFrontRegardless()
    confettiWindow = overlay
    Task { @MainActor in
      try? await Task.sleep(for: .seconds(OnboardingTiming.confetti + 0.12))
      overlay.orderOut(nil)
      if self.confettiWindow === overlay {
        self.confettiWindow = nil
      }
      self.finish()
    }
  }

  private func cancelPermissionWatch() {
    permissionSession?.cancel()
    permissionSession = nil
  }

  private func installKeyMonitor() {
    guard keyMonitor == nil else {
      return
    }
    let box = OnboardingBox(self)
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let keyCode = event.keyCode
      let modifiers = UInt32(event.modifierFlags.rawValue)
      let handled = MainActor.assumeIsolated {
        box.value?.handle(keyCode: keyCode, modifiers: modifiers) ?? false
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
}

private struct OnboardingBox: @unchecked Sendable {
  weak var value: OnboardingController?

  init(_ value: OnboardingController) {
    self.value = value
  }
}

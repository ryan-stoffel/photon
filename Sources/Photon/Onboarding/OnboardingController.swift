import AppKit
import Carbon
import PhotonKeybinds
import SwiftUI

@MainActor
final class OnboardingController: ObservableObject {
  @Published private(set) var step: OnboardingStep = .reveal
  @Published var hotkey: HotkeyCombo
  @Published private(set) var permissionNotice: String?
  @Published private(set) var permissionWaiting = false
  @Published private(set) var revealStarted = Date()
  /// Set when the reveal is skipped early so the backdrop can still fade in.
  @Published private(set) var revealEnded: Date?
  @Published private(set) var confettiStarted: Date?
  @Published private(set) var keysPressed = false

  var onFinish: (() -> Void)?
  var onPermissionResolved: (() -> Void)?

  private var window: OnboardingWindow?
  private var keyMonitor: Any?
  private var schedule: Task<Void, Never>?
  private var keyRelease: Task<Void, Never>?
  private var permissionSession: OnboardingPermissionSession?
  private var finished = false
  private var celebrated = false
  private var permissionSettled = false

  init(hotkey: HotkeyCombo) {
    self.hotkey = hotkey
  }

  /// Settled frames for the parity harness: no timers, every curve at its end.
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
    confettiStarted = nil
    keysPressed = false
    revealEnded = nil
    revealStarted = Date()
    step = .reveal
    if window == nil {
      let host = NSHostingView(rootView: OnboardingView(model: self))
      window = OnboardingChrome.makeWindow(host: host)
    }
    guard let window else {
      return
    }
    window.alphaValue = 1
    window.level = .floating
    window.setFrame(OnboardingChrome.windowFrame(), display: true)
    installKeyMonitor()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
    Task { @MainActor in
      window.invalidateShadow()
    }
    armAutoAdvance()
  }

  func advance() {
    cancelSchedule()
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
    if step == .reveal, revealEnded == nil {
      revealEnded = Date()
    }
    if instant {
      step = next
    } else {
      withAnimation(stepAnimation) {
        step = next
      }
    }
    armAutoAdvance()
  }

  func grantPermission() {
    guard case let .permission(kind) = step, !permissionSettled, !permissionWaiting, !instant else {
      return
    }
    permissionWaiting = true
    // Below the system prompt while it is up; restored on resolution.
    window?.level = .normal
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
    withAnimation(.easeInOut(duration: 0.3)) {
      permissionNotice = kind.withheld
    }
    scheduleAdvance(after: OnboardingTiming.permissionNotice)
  }

  /// The real launcher hotkey opened the panel while the try-it step waited.
  func noteLauncherOpened(visible: Bool, frame: NSRect) {
    guard isWaitingForLauncher, visible, frame.width > 1 else {
      return
    }
    celebrated = true
    cancelSchedule()
    removeKeyMonitor()
    pressKeys()
    confettiStarted = Date()
    scheduleAdvance(after: OnboardingTiming.confetti)
  }

  func finish() {
    guard !finished else {
      return
    }
    finished = true
    cancelSchedule()
    cancelPermissionWatch()
    removeKeyMonitor()
    keyRelease?.cancel()
    keyRelease = nil
    FirstLaunch.markInteractiveOnboardingComplete()
    window?.orderOut(nil)
    let callback = onFinish
    onFinish = nil
    callback?()
  }

  func atmosphere(at date: Date, reduceMotion: Bool) -> Double {
    if instant {
      return 1
    }
    let clock = OnboardingRevealClock(time: date.timeIntervalSince(revealStarted), reduceMotion: reduceMotion)
    guard let revealEnded else {
      return clock.atmosphere
    }
    let ramp = date.timeIntervalSince(revealEnded) / OnboardingTiming.reducedCrossfade
    return max(clock.atmosphere, OnboardingTiming.clamp(ramp))
  }

  /// Escape skips any step except permissions. Return and Space move on where
  /// there is no other action to take. Anything with Command passes through.
  func handle(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
    guard window?.isKeyWindow == true, !modifiers.contains(.command) else {
      return false
    }
    if keyCode == UInt16(kVK_Escape) {
      if !step.isPermission {
        advance()
      }
      return true
    }
    if isReturn(keyCode), step.isPermission {
      grantPermission()
      return true
    }
    if isAdvanceKey(keyCode), step == .reveal || step.isFeature {
      advance()
      return true
    }
    return false
  }

  private var stepAnimation: Animation {
    .spring(response: OnboardingTiming.stepResponse, dampingFraction: OnboardingTiming.stepDamping)
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
    window?.level = .floating
    NSApp.activate(ignoringOtherApps: true)
    window?.makeKeyAndOrderFront(nil)
    if granted {
      advance()
      return
    }
    withAnimation(.easeInOut(duration: 0.3)) {
      permissionNotice = kind.withheld
    }
    scheduleAdvance(after: OnboardingTiming.permissionNotice)
  }

  private func pressKeys() {
    keysPressed = true
    keyRelease?.cancel()
    keyRelease = Task { @MainActor in
      try? await Task.sleep(for: .seconds(OnboardingTiming.keyPress))
      guard !Task.isCancelled else {
        return
      }
      keysPressed = false
    }
  }

  private func armAutoAdvance() {
    guard step == .reveal else {
      return
    }
    scheduleAdvance(after: OnboardingTiming.revealDuration(reduceMotion: reduceMotion))
  }

  private func scheduleAdvance(after seconds: TimeInterval) {
    cancelSchedule()
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

  private func cancelSchedule() {
    let pending = schedule
    schedule = nil
    pending?.cancel()
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
      let modifiers = event.modifierFlags.rawValue
      let handled = MainActor.assumeIsolated {
        box.value?.handle(keyCode: keyCode, modifiers: NSEvent.ModifierFlags(rawValue: modifiers)) ?? false
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

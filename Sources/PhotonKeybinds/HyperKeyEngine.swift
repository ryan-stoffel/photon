import CoreGraphics
import Foundation

/// Turns the (HID-remapped) Hyper key into Control + Option + Shift + Command while it is held.
///
/// A session-level `CGEventTap` swallows the Hyper key itself, adds the four modifier flags to every
/// key event typed while it is down, and dispatches keys that have a Hyper shortcut bound in Photon.
/// A quick press without another key runs the configured tap behaviour.
///
/// When Caps Lock is the Hyper source, the tap also watches `flagsChanged` and the Caps Lock key
/// code and holds the lock at its latched state: off, unless a "Toggle Caps Lock" tap turned it on.
///
/// The tap runs on the main run loop; state is guarded by a lock because the callback is plain C.
public final class HyperKeyEngine: @unchecked Sendable {
  public struct Configuration: Equatable, Sendable {
    public var hyperKeyCode: UInt16
    public var tapBehavior: HyperTapBehavior
    /// Keys with a Hyper shortcut. They are swallowed and reported through `onHyperShortcut`.
    public var boundKeyCodes: Set<UInt16>
    public var tapThreshold: TimeInterval
    /// When true, the Caps Lock lock state is held at the latched value on Hyper down/up and flagsChanged.
    public var suppressCapsLock: Bool

    public init(
      hyperKeyCode: UInt16 = HyperKeySource.destinationKeyCode,
      tapBehavior: HyperTapBehavior = .nothing,
      boundKeyCodes: Set<UInt16> = [],
      tapThreshold: TimeInterval = 0.4,
      suppressCapsLock: Bool = false
    ) {
      self.hyperKeyCode = hyperKeyCode
      self.tapBehavior = tapBehavior
      self.boundKeyCodes = boundKeyCodes
      self.tapThreshold = tapThreshold
      self.suppressCapsLock = suppressCapsLock
    }
  }

  public enum StartError: LocalizedError {
    case tapCreationFailed

    public var errorDescription: String? {
      "macOS refused to create the keyboard event tap. Grant Photon Accessibility access and try again."
    }
  }

  private enum Decision {
    case pass
    case swallow
    case shortcut(UInt16)
    case tap(HyperTapBehavior)
  }

  /// Caps Lock virtual key code (`kVK_CapsLock`).
  public static let capsLockKeyCode: UInt16 = 57

  private static var hyperFlags: CGEventFlags {
    CGEventFlags(rawValue: KeyModifiers.hyper.cgEventFlags)
  }

  /// Called on the main queue with the key code of a bound Hyper shortcut.
  public var onHyperShortcut: (@Sendable (UInt16) -> Void)? {
    get { lock.withLock { shortcutHandler } }
    set { lock.withLock { shortcutHandler = newValue } }
  }

  /// Hook for tests. Receives the Caps Lock state to enforce while Caps Lock is Hyper.
  /// Without a hook the engine sets `CapsLockState` itself.
  public var onSuppressCapsLock: (@Sendable (Bool) -> Void)? {
    get { lock.withLock { suppressHandler } }
    set { lock.withLock { suppressHandler = newValue } }
  }

  private let lock = NSLock()
  private var shortcutHandler: (@Sendable (UInt16) -> Void)?
  private var suppressHandler: (@Sendable (Bool) -> Void)?
  private var configuration = Configuration()
  private var tap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var suspended = false

  private var hyperDown = false
  private var hyperUsed = false
  private var hyperDownAt: TimeInterval = 0
  private var modifiedKeys = Set<Int64>()
  private var swallowedKeys = Set<Int64>()
  /// Caps Lock state a "Toggle Caps Lock" tap asked for. Suppression enforces it instead of always off.
  private var capsLockLatched = false

  public init() {}

  deinit {
    stop()
  }

  public var isRunning: Bool {
    lock.withLock { tap != nil }
  }

  public func update(_ configuration: Configuration) {
    lock.withLock {
      self.configuration = configuration
      if !configuration.suppressCapsLock || configuration.tapBehavior != .capsLock {
        capsLockLatched = false
      }
    }
  }

  /// While suspended (a shortcut recorder is active) Hyper still adds modifier flags, but bound keys
  /// are passed through instead of being dispatched, so they can be recorded.
  public func setSuspended(_ suspended: Bool) {
    lock.withLock { self.suspended = suspended }
  }

  public func start() throws {
    lock.lock()
    defer { lock.unlock() }
    guard tap == nil else {
      return
    }
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
      | CGEventMask(1 << CGEventType.keyUp.rawValue)
      | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
    guard let port = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: hyperKeyTapCallback,
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) else {
      throw StartError.tapCreationFailed
    }
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: port, enable: true)
    tap = port
    runLoopSource = source
    resetState()
    // Toggle mode keeps the Caps Lock state the user had when Hyper started, not a latch from a previous run.
    capsLockLatched = configuration.suppressCapsLock && configuration.tapBehavior == .capsLock && CapsLockState.isOn
  }

  public func stop() {
    lock.lock()
    defer { lock.unlock() }
    if let tap {
      CGEvent.tapEnable(tap: tap, enable: false)
      CFMachPortInvalidate(tap)
    }
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    tap = nil
    runLoopSource = nil
    resetState()
  }

  func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      // Key-ups that arrived while the tap was off are lost, so drop Hyper state instead of leaving it held.
      let tap = lock.withLock { () -> CFMachPort? in
        resetState()
        return self.tap
      }
      if let tap {
        CGEvent.tapEnable(tap: tap, enable: true)
      }
      return Unmanaged.passUnretained(event)
    }
    if type == .flagsChanged {
      return handleFlagsChanged(event)
    }
    guard type == .keyDown || type == .keyUp else {
      return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0
    let decision = decide(type: type, keyCode: keyCode, isRepeat: isRepeat, event: event)

    switch decision {
    case .pass:
      return Unmanaged.passUnretained(event)
    case .swallow:
      return nil
    case let .shortcut(code):
      if let handler = onHyperShortcut {
        DispatchQueue.main.async { handler(code) }
      }
      return nil
    case let .tap(behavior):
      DispatchQueue.main.async { Self.performTap(behavior) }
      return nil
    }
  }

  private func handleFlagsChanged(_ event: CGEvent) -> Unmanaged<CGEvent>? {
    let (suppress, latched) = lock.withLock { (configuration.suppressCapsLock, capsLockLatched) }
    guard suppress else {
      return Unmanaged.passUnretained(event)
    }
    let keyCode = UInt16(truncatingIfNeeded: event.getIntegerValueField(.keyboardEventKeycode))
    let capsOn = event.flags.contains(.maskAlphaShift)
    if capsOn != latched || keyCode == Self.capsLockKeyCode {
      enforceCapsLock(latched)
    }
    if !latched {
      event.flags.remove(.maskAlphaShift)
    }
    if keyCode == Self.capsLockKeyCode {
      return nil
    }
    return Unmanaged.passUnretained(event)
  }

  private func decide(type: CGEventType, keyCode: Int64, isRepeat: Bool, event: CGEvent) -> Decision {
    lock.lock()
    defer { lock.unlock() }

    if isHyperKey(keyCode) {
      return handleHyperKey(down: type == .keyDown, isRepeat: isRepeat)
    }

    if type == .keyDown {
      guard hyperDown else {
        return .pass
      }
      hyperUsed = true
      if !suspended, configuration.boundKeyCodes.contains(UInt16(truncatingIfNeeded: keyCode)) {
        swallowedKeys.insert(keyCode)
        return isRepeat ? .swallow : .shortcut(UInt16(truncatingIfNeeded: keyCode))
      }
      event.flags.formUnion(Self.hyperFlags)
      modifiedKeys.insert(keyCode)
      return .pass
    }

    if swallowedKeys.remove(keyCode) != nil {
      return .swallow
    }
    if modifiedKeys.remove(keyCode) != nil {
      event.flags.formUnion(Self.hyperFlags)
    }
    return .pass
  }

  private func isHyperKey(_ keyCode: Int64) -> Bool {
    if keyCode == Int64(configuration.hyperKeyCode) {
      return true
    }
    return configuration.suppressCapsLock && keyCode == Int64(Self.capsLockKeyCode)
  }

  private func handleHyperKey(down: Bool, isRepeat: Bool) -> Decision {
    if down {
      if configuration.suppressCapsLock {
        enforceCapsLockLocked()
      }
      if !hyperDown, !isRepeat {
        hyperDown = true
        hyperUsed = false
        hyperDownAt = ProcessInfo.processInfo.systemUptime
      }
      return .swallow
    }
    let wasDown = hyperDown
    hyperDown = false
    let held = ProcessInfo.processInfo.systemUptime - hyperDownAt
    if wasDown, !hyperUsed, held < configuration.tapThreshold, configuration.tapBehavior != .nothing {
      guard configuration.suppressCapsLock, configuration.tapBehavior == .capsLock else {
        return .tap(configuration.tapBehavior)
      }
      // Suppression would undo a plain toggle, so the tap flips the state it enforces.
      capsLockLatched.toggle()
    }
    if configuration.suppressCapsLock {
      enforceCapsLockLocked()
    }
    return .swallow
  }

  private func enforceCapsLock(_ on: Bool) {
    Self.setCapsLock(on, handler: onSuppressCapsLock)
  }

  /// Enforces `capsLockLatched`. Caller already holds `lock`.
  private func enforceCapsLockLocked() {
    let handler = suppressHandler
    let on = capsLockLatched
    lock.unlock()
    Self.setCapsLock(on, handler: handler)
    lock.lock()
  }

  private static func setCapsLock(_ on: Bool, handler: (@Sendable (Bool) -> Void)?) {
    if let handler {
      handler(on)
    } else if CapsLockState.isOn != on {
      CapsLockState.set(on)
    }
  }

  private func resetState() {
    hyperDown = false
    hyperUsed = false
    modifiedKeys.removeAll()
    swallowedKeys.removeAll()
  }

  private static func performTap(_ behavior: HyperTapBehavior) {
    switch behavior {
    case .nothing:
      break
    case .escape:
      postKey(53)
    case .capsLock:
      CapsLockState.toggle()
    }
  }

  private static func postKey(_ keyCode: CGKeyCode) {
    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
          let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
    else {
      return
    }
    down.post(tap: .cghidEventTap)
    up.post(tap: .cghidEventTap)
  }
}

private func hyperKeyTapCallback(
  proxy _: CGEventTapProxy,
  type: CGEventType,
  event: CGEvent,
  userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
  guard let userInfo else {
    return Unmanaged.passUnretained(event)
  }
  let engine = Unmanaged<HyperKeyEngine>.fromOpaque(userInfo).takeUnretainedValue()
  return engine.handle(type: type, event: event)
}

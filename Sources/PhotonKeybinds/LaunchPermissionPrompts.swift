import AppKit
import Foundation

/// System prompts Photon already requests. Folder panels stay user-initiated.
public enum LaunchPermissionPrompt: String, Equatable, Sendable, CaseIterable {
  case accessibility
  case inputMonitoring
}

public enum LaunchPermissionOrder {
  /// Accessibility, then Input Monitoring. There is no further system prompt.
  public static let prompts: [LaunchPermissionPrompt] = [
    .accessibility,
    .inputMonitoring,
  ]
}

/// Runs prompts one after another. The next `request` starts only after the previous one returns.
@MainActor
public struct LaunchPermissionRunner {
  public var prompts: [LaunchPermissionPrompt]

  public init(prompts: [LaunchPermissionPrompt] = LaunchPermissionOrder.prompts) {
    self.prompts = prompts
  }

  public func run(_ request: (LaunchPermissionPrompt) async -> Void) async {
    for prompt in prompts {
      await request(prompt)
    }
  }
}

enum OnScreenWindowSnapshot {
  static func capture() -> [PermissionDialogWindow] {
    guard let raw = CGWindowListCopyWindowInfo(
      [.optionOnScreenOnly, .excludeDesktopElements],
      kCGNullWindowID
    ) as? [[String: Any]] else {
      return []
    }
    return raw.compactMap(parse)
  }

  private static func parse(_ info: [String: Any]) -> PermissionDialogWindow? {
    guard let id = uint32(info[kCGWindowNumber as String]) else {
      return nil
    }
    let bounds = info[kCGWindowBounds as String] as? [String: Any] ?? [:]
    return PermissionDialogWindow(
      id: id,
      width: double(bounds["Width"]),
      height: double(bounds["Height"]),
      ownerName: info[kCGWindowOwnerName as String] as? String ?? "",
      title: info[kCGWindowName as String] as? String ?? ""
    )
  }

  private static func uint32(_ value: Any?) -> UInt32? {
    if let number = value as? NSNumber {
      return number.uint32Value
    }
    if let number = value as? Int {
      return UInt32(number)
    }
    return nil
  }

  private static func double(_ value: Any?) -> Double {
    if let number = value as? NSNumber {
      return number.doubleValue
    }
    if let number = value as? Double {
      return number
    }
    return 0
  }
}

enum PermissionDialogWaiter {
  static let appearTimeout: TimeInterval = 5
  static let closeTimeout: TimeInterval = 30 * 60
  private static let pollNanoseconds: UInt64 = 100_000_000

  /// Returns when the prompt is granted, the new dialog closes, or no dialog appears.
  @MainActor
  static func wait(
    baseline: [PermissionDialogWindow],
    shouldContinue: @MainActor () -> Bool,
    granted: @MainActor () -> Bool
  ) async {
    let ids = Set(baseline.map(\.id))
    var phase = PermissionDialogGate.Phase.waitingToAppear
    let started = Date()
    var closingSince: Date?
    while shouldContinue(), !Task.isCancelled {
      phase = PermissionDialogGate.advance(
        phase: phase,
        granted: granted(),
        baseline: ids,
        windows: OnScreenWindowSnapshot.capture(),
        appearTimedOut: Date().timeIntervalSince(started) >= appearTimeout
      )
      if phase == .finished {
        return
      }
      if case .waitingToClose = phase {
        if closingSince == nil {
          closingSince = Date()
        }
        if let closingSince, Date().timeIntervalSince(closingSince) >= closeTimeout {
          return
        }
      }
      try? await Task.sleep(nanoseconds: pollNanoseconds)
    }
  }
}

enum LaunchPermissionPrompts {
  /// Shows each system dialog and does not start the next until this one has been answered.
  @MainActor
  static func run(shouldContinue: @MainActor () -> Bool) async {
    await LaunchPermissionRunner().run { prompt in
      guard shouldContinue() else {
        return
      }
      switch prompt {
      case .accessibility:
        await requestAccessibility(shouldContinue: shouldContinue)
      case .inputMonitoring:
        await requestInputMonitoring(shouldContinue: shouldContinue)
      }
    }
  }

  @MainActor
  private static func requestAccessibility(shouldContinue: @MainActor () -> Bool) async {
    guard shouldContinue(), !AccessibilityPermission.isTrusted else {
      return
    }
    let baseline = OnScreenWindowSnapshot.capture()
    _ = AccessibilityPermission.requestTrust()
    await PermissionDialogWaiter.wait(
      baseline: baseline,
      shouldContinue: shouldContinue,
      granted: { AccessibilityPermission.isTrusted }
    )
  }

  @MainActor
  private static func requestInputMonitoring(shouldContinue: @MainActor () -> Bool) async {
    guard shouldContinue(), !AccessibilityPermission.hasInputMonitoring else {
      return
    }
    let baseline = OnScreenWindowSnapshot.capture()
    let started = Date()
    // Same call the app already makes. When it blocks, the user has answered before we return.
    let granted = AccessibilityPermission.requestInputMonitoring()
    if granted || AccessibilityPermission.hasInputMonitoring || !shouldContinue() {
      return
    }
    // A blocking Input Monitoring call already waited for the answer.
    if Date().timeIntervalSince(started) > 0.35 {
      return
    }
    await PermissionDialogWaiter.wait(
      baseline: baseline,
      shouldContinue: shouldContinue,
      granted: { AccessibilityPermission.hasInputMonitoring }
    )
  }
}

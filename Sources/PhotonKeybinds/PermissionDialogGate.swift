import Foundation

/// One on-screen window, reduced to what the permission waiter needs.
public struct PermissionDialogWindow: Equatable, Sendable {
  public var id: UInt32
  public var width: Double
  public var height: Double
  public var ownerName: String
  public var title: String

  public init(
    id: UInt32,
    width: Double,
    height: Double,
    ownerName: String,
    title: String
  ) {
    self.id = id
    self.width = width
    self.height = height
    self.ownerName = ownerName
    self.title = title
  }
}

/// Decides when one system permission dialog has been answered, without showing the next.
public enum PermissionDialogGate {
  public enum Phase: Equatable, Sendable {
    case waitingToAppear
    case waitingToClose
    case finished
  }

  public static let minimumPromptWidth: Double = 260
  public static let maximumPromptWidth: Double = 760
  public static let minimumPromptHeight: Double = 110
  public static let maximumPromptHeight: Double = 460

  /// Alert-sized windows, plus the processes macOS uses for the Accessibility prompt.
  public static func isSystemPrompt(_ window: PermissionDialogWindow) -> Bool {
    if isPromptSized(window) {
      return true
    }
    let owner = window.ownerName.lowercased()
    let knownOwners = ["universalaccessauthwarn", "securityagent", "coreservicesuiagent"]
    guard knownOwners.contains(where: { owner.contains($0) }) else {
      return false
    }
    return window.width >= 200 && window.height >= 80
  }

  public static func appearedIDs(
    baseline: Set<UInt32>,
    windows: [PermissionDialogWindow]
  ) -> Set<UInt32> {
    Set(windows.compactMap { window in
      guard !baseline.contains(window.id), isSystemPrompt(window) else {
        return nil
      }
      return window.id
    })
  }

  /// `granted` finishes the wait even if the dialog is still on screen.
  /// A dialog that never appears is treated as already decided once `appearTimedOut` is set.
  public static func advance(
    phase: Phase,
    granted: Bool,
    baseline: Set<UInt32>,
    windows: [PermissionDialogWindow],
    appearTimedOut: Bool
  ) -> Phase {
    if granted {
      return .finished
    }
    let appeared = appearedIDs(baseline: baseline, windows: windows)
    switch phase {
    case .waitingToAppear:
      if !appeared.isEmpty {
        return .waitingToClose
      }
      if appearTimedOut {
        return .finished
      }
      return .waitingToAppear
    case .waitingToClose:
      if appeared.isEmpty {
        return .finished
      }
      return .waitingToClose
    case .finished:
      return .finished
    }
  }

  private static func isPromptSized(_ window: PermissionDialogWindow) -> Bool {
    window.width >= minimumPromptWidth
      && window.width <= maximumPromptWidth
      && window.height >= minimumPromptHeight
      && window.height <= maximumPromptHeight
  }
}

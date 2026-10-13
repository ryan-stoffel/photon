import AppKit
import Combine

/// Live set of running regular (Dock) application bundle identifiers for Dock-style launcher dots.
/// Menu bar and background agents are left out because the Dock shows no dot for them.
@MainActor
public final class RunningApplications: ObservableObject {
  @Published public private(set) var bundleIdentifiers: Set<String> = []

  private var observations: [NSObjectProtocol] = []

  public init() {
    refresh()
  }

  public func start() {
    stop()
    refresh()
    let center = NSWorkspace.shared.notificationCenter
    let names: [Notification.Name] = [
      NSWorkspace.didLaunchApplicationNotification,
      NSWorkspace.didTerminateApplicationNotification,
    ]
    for name in names {
      observations.append(
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          Task { @MainActor in
            self?.refresh()
          }
        }
      )
    }
  }

  public func stop() {
    let center = NSWorkspace.shared.notificationCenter
    for observation in observations {
      center.removeObserver(observation)
    }
    observations.removeAll()
  }

  public func refresh() {
    bundleIdentifiers = Set(
      NSWorkspace.shared.runningApplications.compactMap { application in
        guard !application.isTerminated, application.activationPolicy == .regular else {
          return nil
        }
        return application.bundleIdentifier
      }
    )
  }

  public func contains(_ bundleIdentifier: String) -> Bool {
    bundleIdentifiers.contains { $0.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }
  }
}

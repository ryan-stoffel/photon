import AppKit
import PhotonKeybinds

/// Watches a system permission prompt until macOS reports granted or denied.
@MainActor
final class OnboardingPermissionSession {
  var onResolve: (@MainActor (Bool) -> Void)?

  private var task: Task<Void, Never>?
  private var baseline: Set<UInt32> = []
  private var sawPrompt = false
  private var sawInactive = false

  func start(request: @MainActor () -> Bool, isGranted: @MainActor () -> Bool) {
    task?.cancel()
    task = nil
    sawPrompt = false
    sawInactive = false
    baseline = OnboardingPromptWindows.ids()
    let started = Date()
    let granted = request()
    if granted || isGranted() {
      finish(true)
      return
    }
    // A blocking prompt (Input Monitoring) returns only after the user answers.
    if Date().timeIntervalSince(started) > 0.4 {
      finish(false)
      return
    }
    task = Task { @MainActor in
      await self.poll(started: started, isGranted: isGranted)
    }
  }

  func cancel() {
    task?.cancel()
    task = nil
    onResolve = nil
  }

  private func finish(_ granted: Bool) {
    let callback = onResolve
    onResolve = nil
    task?.cancel()
    task = nil
    callback?(granted)
  }

  private func poll(started: Date, isGranted: @MainActor () -> Bool) async {
    let deadline = Date().addingTimeInterval(90)
    var quietSince: Date?
    while !Task.isCancelled, Date() < deadline {
      try? await Task.sleep(for: .milliseconds(200))
      if Task.isCancelled {
        return
      }
      if isGranted() {
        finish(true)
        return
      }
      if !NSApp.isActive {
        sawInactive = true
      }
      let current = OnboardingPromptWindows.ids()
      if !current.subtracting(baseline).isEmpty {
        sawPrompt = true
        quietSince = nil
      } else if sawPrompt {
        quietSince = quietSince ?? Date()
      }
      let promptGone = quietSince.map { Date().timeIntervalSince($0) > 0.35 } ?? false
      let returned = sawInactive && NSApp.isActive && Date().timeIntervalSince(started) > 0.8
      if promptGone || returned {
        finish(isGranted())
        return
      }
    }
    if !Task.isCancelled {
      finish(isGranted())
    }
  }
}

enum OnboardingPromptWindows {
  private static let owners: Set<String> = [
    "tccd",
    "universalAccessAuthWarn",
    "CoreServicesUIAgent",
    "UserNotificationCenter",
  ]

  static func ids() -> Set<UInt32> {
    let options = CGWindowListOption(arrayLiteral: .optionOnScreenOnly, .excludeDesktopElements)
    guard let raw = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
      return []
    }
    var ids = Set<UInt32>()
    for window in raw {
      guard let owner = window[kCGWindowOwnerName as String] as? String, owners.contains(owner) else {
        continue
      }
      if let number = window[kCGWindowNumber as String] as? CGWindowID {
        ids.insert(number)
      }
    }
    return ids
  }
}

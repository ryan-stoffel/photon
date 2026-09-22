import AppKit

/// Separate from the 0.4.6 revision so installs that already finished that window see this once.
enum Phase1Launch {
  static let completedKey = "hasCompletedPhase1Onboarding"

  static func needsPresentation(_ defaults: UserDefaults = .standard) -> Bool {
    !defaults.bool(forKey: completedKey)
  }

  static func markComplete(_ defaults: UserDefaults = .standard) {
    defaults.set(true, forKey: completedKey)
  }

  static func reset(_ defaults: UserDefaults = .standard) {
    defaults.set(false, forKey: completedKey)
  }
}

extension AppRuntime {
  func presentFirstLaunch() {
    guard Phase1Launch.needsPresentation() else {
      SpotlightConflict.adviseIfNeeded(current: settings.hotkey)
      keybinds.adviseAccessibilityIfNeeded()
      return
    }
    let controller = makePhase1()
    controller.onFinish = { [weak self] in
      Phase1Launch.markComplete()
      self?.keybinds.acknowledgeAccessibilityGuidance()
      guard let self else {
        return
      }
      SpotlightConflict.adviseIfNeeded(current: settings.hotkey)
    }
    controller.present(settled: false)
  }

  func replayOnboarding() {
    Phase1Launch.reset()
    closeSettings()
    presentFirstLaunch()
  }

  func makePhase1() -> Phase1OverlayController {
    if let phase1 {
      return phase1
    }
    let controller = Phase1OverlayController()
    phase1 = controller
    return controller
  }
}

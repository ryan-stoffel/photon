import AppKit

/// Separate from `hasCompletedPhase1Onboarding`, so a finished cinematic overlay does not skip this note.
enum WelcomeLaunch {
  static let completedKey = "hasSeenMinimalWelcome"

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
    guard WelcomeLaunch.needsPresentation() else {
      SpotlightConflict.adviseIfNeeded(current: settings.hotkey)
      keybinds.adviseAccessibilityIfNeeded()
      return
    }
    let controller = makeWelcome()
    controller.onFinish = { [weak self] in
      WelcomeLaunch.markComplete()
      self?.keybinds.acknowledgeAccessibilityGuidance()
      guard let self else {
        return
      }
      SpotlightConflict.adviseIfNeeded(current: settings.hotkey)
    }
    controller.onGrant = { [weak self] in
      guard let self else {
        return
      }
      let generation = self.welcome?.presentationGeneration
      await self.keybinds.requestLaunchPermissionsInOrder {
        guard let welcome = self.welcome else {
          return false
        }
        return welcome.isVisible && welcome.presentationGeneration == generation
      }
    }
    controller.present(hotkey: settings.hotkey)
  }

  func replayOnboarding() {
    WelcomeLaunch.reset()
    closeSettings()
    presentFirstLaunch()
  }

  func makeWelcome() -> WelcomeController {
    if let welcome {
      return welcome
    }
    let controller = WelcomeController()
    welcome = controller
    return controller
  }
}

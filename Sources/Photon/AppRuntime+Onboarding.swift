import AppKit

extension AppRuntime {
  func presentFirstLaunch() {
    let defaults = UserDefaults.standard
    guard FirstLaunch.needsInteractiveOnboarding(defaults) else {
      SpotlightConflict.adviseIfNeeded(current: settings.hotkey)
      keybinds.adviseAccessibilityIfNeeded()
      return
    }
    let controller = makeOnboarding()
    controller.onFinish = { [weak self] in
      guard let self else {
        return
      }
      SpotlightConflict.adviseIfNeeded(current: settings.hotkey)
    }
    controller.onPermissionResolved = { [weak self] in
      self?.keybinds.acknowledgeAccessibilityGuidance()
      self?.keybinds.refreshAfterPermissionPrompt()
    }
    controller.present(hotkey: settings.hotkey)
  }

  func replayOnboarding() {
    FirstLaunch.resetOnboarding()
    closeSettings()
    presentFirstLaunch()
  }

  func makeOnboarding() -> OnboardingController {
    if let onboarding {
      return onboarding
    }
    let controller = OnboardingController(hotkey: settings.hotkey)
    onboarding = controller
    return controller
  }
}

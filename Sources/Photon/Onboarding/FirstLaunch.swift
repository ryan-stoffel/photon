import Foundation

enum FirstLaunch {
  static let permissionsKey = "hasRequestedFirstLaunchPermissions"
  static let onboardingKey = "hasCompletedOnboarding"
  /// 0.4.3 stored only `hasCompletedOnboarding`. Revision 2 is the 0.4.4 dialog
  /// tour. Revision 3 is the full-screen sequence, so those installs see it once.
  static let onboardingRevisionKey = "onboardingRevision"
  static let cinematicOnboardingRevision = 3

  static func needsInteractiveOnboarding(_ defaults: UserDefaults = .standard) -> Bool {
    defaults.integer(forKey: onboardingRevisionKey) < cinematicOnboardingRevision
  }

  static func markInteractiveOnboardingComplete(_ defaults: UserDefaults = .standard) {
    defaults.set(true, forKey: onboardingKey)
    defaults.set(true, forKey: permissionsKey)
    defaults.set(cinematicOnboardingRevision, forKey: onboardingRevisionKey)
  }

  static func resetOnboarding(_ defaults: UserDefaults = .standard) {
    defaults.set(false, forKey: onboardingKey)
    defaults.removeObject(forKey: onboardingRevisionKey)
  }
}

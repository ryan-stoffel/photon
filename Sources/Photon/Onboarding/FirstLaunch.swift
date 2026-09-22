import Foundation

enum FirstLaunch {
  static let permissionsKey = "hasRequestedFirstLaunchPermissions"
  static let onboardingKey = "hasCompletedOnboarding"
  /// 0.4.3 stored only `hasCompletedOnboarding`, including for people who skipped
  /// the plain tour. Revision 2 is the interactive walkthrough.
  static let onboardingRevisionKey = "onboardingRevision"
  static let interactiveOnboardingRevision = 2

  static func needsInteractiveOnboarding(_ defaults: UserDefaults = .standard) -> Bool {
    defaults.integer(forKey: onboardingRevisionKey) < interactiveOnboardingRevision
  }

  static func markInteractiveOnboardingComplete(_ defaults: UserDefaults = .standard) {
    defaults.set(true, forKey: onboardingKey)
    defaults.set(interactiveOnboardingRevision, forKey: onboardingRevisionKey)
  }
}

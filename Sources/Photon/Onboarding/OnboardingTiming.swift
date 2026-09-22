import CoreGraphics
import Foundation

/// Every cinematic duration lives here. Views and the controller share these values.
enum OnboardingTiming {
  /// Beam travel from the left edge to center.
  static let beam: TimeInterval = 1.5
  /// Full-white hold after the beam arrives.
  static let flash: TimeInterval = 0.2
  /// Flash fade while the mark appears.
  static let flashFade: TimeInterval = 0.45
  /// How long the mark stays before the next step.
  static let revealHold: TimeInterval = 1.05
  /// Reduce Motion replacement for the beam and flash.
  static let reducedCrossfade: TimeInterval = 0.7
  /// Content fade and slide between steps. The backdrop does not use this.
  static let content: TimeInterval = 0.48
  static let contentSlide: CGFloat = 22
  /// Reading time on a feature screen before it advances on its own.
  static let featureHold: TimeInterval = 5.2
  /// How long a skip or denial sentence stays on a permission screen.
  static let permissionNotice: TimeInterval = 1.8
  static let bobPeriod: TimeInterval = 3.4
  static let bobDistance: CGFloat = 7
  static let confetti: TimeInterval = 0.95

  static func revealDuration(reduceMotion: Bool) -> TimeInterval {
    if reduceMotion {
      return reducedCrossfade + revealHold
    }
    return beam + flash + flashFade + revealHold
  }
}

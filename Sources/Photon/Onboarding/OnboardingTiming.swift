import CoreGraphics
import Foundation

/// Every onboarding duration lives here. Views and the controller share these values.
enum OnboardingTiming {
  /// Fully black before the beam.
  static let revealBlack: TimeInterval = 0.4
  /// Beam travel from the left edge to center.
  static let beam: TimeInterval = 1.4
  /// Full-white hold after the beam collapses.
  static let flashPeak: TimeInterval = 0.15
  /// Flash fade while the mark scales in.
  static let flashDecay: TimeInterval = 0.5
  /// How long the mark stays before the next step.
  static let revealHold: TimeInterval = 1.2
  /// Reduce Motion replacement for the beam and flash.
  static let reducedCrossfade: TimeInterval = 0.7
  /// Spring response for the content crossfade. The backdrop does not use this.
  static let content: TimeInterval = 0.52
  static let contentSlide: CGFloat = 24
  /// Reading time on a feature screen before it advances on its own.
  static let featureHold: TimeInterval = 5.2
  /// How long a skip or denial sentence stays on a permission screen.
  static let permissionNotice: TimeInterval = 1.8
  static let bobPeriod: TimeInterval = 3.4
  static let bobDistance: CGFloat = 6
  /// Muted burst after the launcher opens. The last portion fades out.
  static let burst: TimeInterval = 1.5
  static let burstFade: TimeInterval = 0.4

  static var flashStart: TimeInterval {
    revealBlack + beam
  }

  static var decayStart: TimeInterval {
    flashStart + flashPeak
  }

  static var holdStart: TimeInterval {
    decayStart + flashDecay
  }

  static func revealDuration(reduceMotion: Bool) -> TimeInterval {
    if reduceMotion {
      return reducedCrossfade + revealHold
    }
    return holdStart + revealHold
  }

  static func easeInOut(_ progress: Double) -> Double {
    let t = min(1, max(0, progress))
    return t * t * (3 - 2 * t)
  }
}

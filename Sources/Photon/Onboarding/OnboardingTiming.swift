import CoreGraphics
import Foundation

/// Every onboarding duration and motion constant. Views and the controller read
/// these; nothing else in the sequence hard-codes a number of seconds.
enum OnboardingTiming {
  // Reveal. The window opens black, a beam crosses to center, collapses, flashes,
  // and the mark settles in as the flash decays.
  static let revealBlack: TimeInterval = 0.4
  static let beam: TimeInterval = 1.4
  static let beamCollapse: TimeInterval = 0.1
  static let flashPeak: TimeInterval = 0.15
  static let flashDecay: TimeInterval = 0.5
  static let revealHold: TimeInterval = 1.2
  /// Reduce Motion replaces the beam, flash, and confetti with this crossfade.
  static let reducedCrossfade: TimeInterval = 0.7

  // Step transitions: content crossfades and slides horizontally on a spring.
  static let stepResponse: TimeInterval = 0.55
  static let stepDamping: Double = 0.86
  static let stepSlide: CGFloat = 24

  // Ambient motion. The background never resets between steps.
  static let glowBreath: TimeInterval = 4.2
  static let ambientDrift: TimeInterval = 26
  /// Star drift in points per second, scaled per star for parallax.
  static let starDrift: CGFloat = 1.6
  static let bobPeriod: TimeInterval = 3.4
  static let bobDistance: CGFloat = 6

  // Permissions and try-it.
  static let permissionNotice: TimeInterval = 1.8
  static let keyPress: TimeInterval = 0.16

  // Confetti after the first successful open. The last portion fades out.
  static let confetti: TimeInterval = 1.5
  static let confettiFade: TimeInterval = 0.4

  enum Confetti {
    static let count = 84
    static let minSize: CGFloat = 4
    static let maxSize: CGFloat = 8
    static let circleShare = 0.36
    static let minSpeed: CGFloat = 260
    static let maxSpeed: CGFloat = 640
    /// Extra upward velocity so the burst fountains before it falls.
    static let lift: CGFloat = 160
    static let gravity: CGFloat = 720
    static let minDrag: CGFloat = 1.6
    static let maxDrag: CGFloat = 2.6
    static let maxSpin: CGFloat = 7
    static let flutterSwing: CGFloat = 70
  }

  static var beamEnd: TimeInterval {
    revealBlack + beam
  }

  /// The flash rises while the beam collapses.
  static var flashStart: TimeInterval {
    beamEnd
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

  static func clamp(_ value: Double) -> Double {
    min(1, max(0, value))
  }

  static func easeInOut(_ progress: Double) -> Double {
    let t = clamp(progress)
    return t * t * (3 - 2 * t)
  }

  static func easeOut(_ progress: Double) -> Double {
    let t = clamp(progress)
    return 1 - (1 - t) * (1 - t)
  }
}

import AppKit
import SwiftUI

/// Every timing, opacity, color, and size for the Phase 1 overlay.
enum Phase1Metrics {
  static let dimOpacity: CGFloat = 0.26
  static let dimColor = Color(red: 0.02, green: 0.03, blue: 0.06)
  static let backgroundFade: TimeInterval = 1.5
  static let beamDuration: TimeInterval = 3.6
  static let beamTailLength: CGFloat = 340
  static let beamThickness: CGFloat = 2.5
  static let beamInnerThickness: CGFloat = 14
  static let beamInnerBlur: CGFloat = 7
  static let beamGlowThickness: CGFloat = 52
  static let beamGlowBlur: CGFloat = 16
  static let beamHeadDiameter: CGFloat = 28
  static let beamHeadBlur: CGFloat = 8
  static let beamMinBrightness: CGFloat = 0.72
  static let beamBloomMin: CGFloat = 0.86
  static let beamBloomMax: CGFloat = 1
  static let beamGlowOpacity: CGFloat = 0.55
  static let beamInnerOpacity: CGFloat = 0.8
  static let beamHeadOpacity: CGFloat = 0.95
  static let beamMinSpan: CGFloat = 0.5
  static let centerFraction: CGFloat = 0.5
  static let fallbackFrame = NSRect(x: 0, y: 0, width: 1440, height: 900)
  static let beamCoreColor = Color(red: 1, green: 0.984, blue: 0.976)
  static let beamGlowColor = Color(red: 0.25, green: 0.7, blue: 1)
  static let flashDuration: TimeInterval = 0.5
  static let flashColor = Color(red: 0.78, green: 0.9, blue: 1)
  static let flashDiameter: CGFloat = 200
  static let flashBlur: CGFloat = 28
  static let flashScaleStart: CGFloat = 0.35
  static let flashScaleEnd: CGFloat = 1.8
  static let iconSize: CGFloat = 108
  static let iconStartScale: CGFloat = 0.82
  static let wordmarkSize: CGFloat = 40
  static let wordmarkGap: CGFloat = 16
  static let wordmarkLineHeight: CGFloat = 48
  static let wordmarkTracking: CGFloat = 0.6
  static let wordmarkColor = Color.white
  static let hazeColor = Color(red: 0.08, green: 0.28, blue: 0.62)
  static let hazePeakOpacity: CGFloat = 0.42
  static let hazeClearStop: CGFloat = 0.52
  static let starCount = 52
  static let starColor = Color.white
  static let starRadiusMin: CGFloat = 0.55
  static let starRadiusMax: CGFloat = 1.25
  static let starMinBrightness: CGFloat = 0.05
  static let starMinPeak: CGFloat = 0.28
  static let starMaxPeak: CGFloat = 0.7
  static let starPeriodMin: TimeInterval = 2.2
  static let starPeriodMax: TimeInterval = 5.6
  static let starTwinkleExponent: Double = 8
  static let starDriftPerSecond: CGFloat = 0.004
  static let starDriftScaleMin: CGFloat = 0.4
  static let starSeed: UInt64 = 0x5048_4f4e
  static let dismissFade: TimeInterval = 0.28
  static let dismissFallbackDelay: TimeInterval = 0.08
  static let windowLevel = NSWindow.Level.screenSaver
  static let collectionBehavior: NSWindow.CollectionBehavior = [
    .fullScreenAuxiliary,
    .transient,
    .ignoresCycle,
    .stationary,
  ]
  static let restingStep = "Photon"

  /// t² so the beam leaves the left edge slowly and arrives at center a little faster.
  static func easeIn(_ t: CGFloat) -> CGFloat {
    let clamped = min(1, max(0, t))
    return clamped * clamped
  }
}

struct Phase1Frame {
  var background: CGFloat
  var beamProgress: CGFloat
  var beamVisible: Bool
  var beamCollapse: CGFloat
  var flashOpacity: CGFloat
  var flashProgress: CGFloat
  var markOpacity: CGFloat
  var markScale: CGFloat
  var isResting: Bool

  static let resting = Phase1Frame(
    background: 1,
    beamProgress: 0,
    beamVisible: false,
    beamCollapse: 1,
    flashOpacity: 0,
    flashProgress: 1,
    markOpacity: 1,
    markScale: 1,
    isResting: true
  )
}

enum Phase1Clock {
  static func frame(elapsed: TimeInterval, settled: Bool, reduceMotion: Bool) -> Phase1Frame {
    if settled {
      return .resting
    }
    if reduceMotion {
      return reduced(elapsed: elapsed)
    }
    return cinematic(elapsed: elapsed)
  }

  private static func reduced(elapsed: TimeInterval) -> Phase1Frame {
    let fade = min(1, max(0, CGFloat(elapsed / Phase1Metrics.backgroundFade)))
    return Phase1Frame(
      background: fade,
      beamProgress: 0,
      beamVisible: false,
      beamCollapse: 0,
      flashOpacity: 0,
      flashProgress: 0,
      markOpacity: fade,
      markScale: 1,
      isResting: elapsed >= Phase1Metrics.backgroundFade
    )
  }

  private static func cinematic(elapsed: TimeInterval) -> Phase1Frame {
    if elapsed <= Phase1Metrics.backgroundFade {
      let fade = min(1, max(0, CGFloat(elapsed / Phase1Metrics.backgroundFade)))
      return hiddenMark(background: fade)
    }
    let afterBackground = elapsed - Phase1Metrics.backgroundFade
    if afterBackground < Phase1Metrics.beamDuration {
      let linear = CGFloat(afterBackground / Phase1Metrics.beamDuration)
      return Phase1Frame(
        background: 1,
        beamProgress: Phase1Metrics.easeIn(linear),
        beamVisible: true,
        beamCollapse: 0,
        flashOpacity: 0,
        flashProgress: 0,
        markOpacity: 0,
        markScale: Phase1Metrics.iconStartScale,
        isResting: false
      )
    }
    let afterBeam = afterBackground - Phase1Metrics.beamDuration
    if afterBeam < Phase1Metrics.flashDuration {
      return flash(progress: CGFloat(afterBeam / Phase1Metrics.flashDuration))
    }
    return .resting
  }

  private static func hiddenMark(background: CGFloat) -> Phase1Frame {
    Phase1Frame(
      background: background,
      beamProgress: 0,
      beamVisible: false,
      beamCollapse: 0,
      flashOpacity: 0,
      flashProgress: 0,
      markOpacity: 0,
      markScale: Phase1Metrics.iconStartScale,
      isResting: false
    )
  }

  private static func flash(progress: CGFloat) -> Phase1Frame {
    let mark = min(1, max(0, (progress - 0.2) / 0.8))
    let scale = Phase1Metrics.iconStartScale + (1 - Phase1Metrics.iconStartScale) * mark
    return Phase1Frame(
      background: 1,
      beamProgress: 1,
      beamVisible: true,
      beamCollapse: Phase1Metrics.easeIn(progress),
      flashOpacity: CGFloat(sin(Double(progress) * .pi)),
      flashProgress: progress,
      markOpacity: mark,
      markScale: scale,
      isResting: false
    )
  }
}

struct Phase1Star {
  var x: CGFloat
  var y: CGFloat
  var radius: CGFloat
  var minBrightness: CGFloat
  var maxBrightness: CGFloat
  var period: TimeInterval
  var phase: TimeInterval
  var driftScale: CGFloat
}

struct Phase1RNG {
  var state: UInt64

  mutating func nextUnit() -> CGFloat {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    return CGFloat(state >> 33) / CGFloat(1 << 31)
  }
}

enum Phase1Stars {
  static let field: [Phase1Star] = generate()

  static func brightness(_ star: Phase1Star, at time: TimeInterval) -> CGFloat {
    let cycle = (time + star.phase).truncatingRemainder(dividingBy: star.period) / star.period
    let peak = pow(max(0, sin(cycle * .pi)), Phase1Metrics.starTwinkleExponent)
    return star.minBrightness + (star.maxBrightness - star.minBrightness) * CGFloat(peak)
  }

  static func origin(_ star: Phase1Star, at time: TimeInterval, in size: CGSize) -> CGPoint {
    let drift = CGFloat(time) * Phase1Metrics.starDriftPerSecond * star.driftScale
    let y = star.y + drift
    let wrapped = y - floor(y)
    return CGPoint(x: star.x * size.width, y: wrapped * size.height)
  }

  private static func generate() -> [Phase1Star] {
    var rng = Phase1RNG(state: Phase1Metrics.starSeed)
    return (0 ..< Phase1Metrics.starCount).map { _ in
      let radiusSpan = Phase1Metrics.starRadiusMax - Phase1Metrics.starRadiusMin
      let peakSpan = Phase1Metrics.starMaxPeak - Phase1Metrics.starMinPeak
      let periodSpan = Phase1Metrics.starPeriodMax - Phase1Metrics.starPeriodMin
      return Phase1Star(
        x: rng.nextUnit(),
        y: rng.nextUnit(),
        radius: Phase1Metrics.starRadiusMin + rng.nextUnit() * radiusSpan,
        minBrightness: Phase1Metrics.starMinBrightness,
        maxBrightness: Phase1Metrics.starMinPeak + rng.nextUnit() * peakSpan,
        period: Phase1Metrics.starPeriodMin + Double(rng.nextUnit()) * periodSpan,
        phase: Double(rng.nextUnit()) * Phase1Metrics.starPeriodMax,
        driftScale: Phase1Metrics.starDriftScaleMin + rng.nextUnit() * (1 - Phase1Metrics.starDriftScaleMin)
      )
    }
  }
}

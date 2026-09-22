import SwiftUI

enum OnboardingColor {
  static let beam = Color(red: 0.45, green: 0.74, blue: 1)
  static let indigo = Color(red: 0.40, green: 0.34, blue: 0.92)
  static let teal = Color(red: 0.16, green: 0.42, blue: 0.62)
  static let secondary = Color.white.opacity(0.64)
  static let tertiary = Color.white.opacity(0.36)
}

/// The dark field inside the window: black, a slow nebula of two or three soft
/// gradients, and faint stars. It sits under every step and never resets.
struct OnboardingBackdrop: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: frameInterval, paused: model.instant)) { context in
      Canvas(rendersAsynchronously: false) { canvas, size in
        canvas.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
        let atmosphere = model.atmosphere(at: context.date, reduceMotion: reduceMotion)
        guard atmosphere > 0.001 else {
          return
        }
        let drift = !reduceMotion && !model.instant
        let time = drift ? context.date.timeIntervalSince(model.revealStarted) : 0
        OnboardingAmbientPainter.drawNebula(&canvas, size: size, time: time, opacity: atmosphere)
        OnboardingAmbientPainter.drawStars(&canvas, size: size, time: time, drift: drift, opacity: atmosphere)
      }
    }
    .allowsHitTesting(false)
    .ignoresSafeArea()
  }

  private var frameInterval: TimeInterval {
    reduceMotion ? 1.0 / 12.0 : 1.0 / 30.0
  }
}

struct OnboardingAmbientBlob {
  var color: Color
  var anchor: CGPoint
  var sway: CGSize
  var radius: CGFloat
  var period: TimeInterval
  var phase: Double
  var alpha: Double

  static let all: [OnboardingAmbientBlob] = [
    OnboardingAmbientBlob(
      color: OnboardingColor.beam,
      anchor: CGPoint(x: 0.28, y: 0.30),
      sway: CGSize(width: 110, height: 60),
      radius: 320,
      period: OnboardingTiming.ambientDrift,
      phase: 0,
      alpha: 0.13
    ),
    OnboardingAmbientBlob(
      color: OnboardingColor.indigo,
      anchor: CGPoint(x: 0.74, y: 0.68),
      sway: CGSize(width: 90, height: 70),
      radius: 360,
      period: OnboardingTiming.ambientDrift * 1.3,
      phase: 2.1,
      alpha: 0.10
    ),
    OnboardingAmbientBlob(
      color: OnboardingColor.teal,
      anchor: CGPoint(x: 0.55, y: 0.12),
      sway: CGSize(width: 70, height: 40),
      radius: 260,
      period: OnboardingTiming.ambientDrift * 1.6,
      phase: 4.0,
      alpha: 0.07
    ),
  ]

  func center(in size: CGSize, time: TimeInterval) -> CGPoint {
    let angle = time / period * .pi * 2 + phase
    return CGPoint(
      x: anchor.x * size.width + CGFloat(cos(angle)) * sway.width,
      y: anchor.y * size.height + CGFloat(sin(angle * 0.8)) * sway.height
    )
  }
}

enum OnboardingAmbientPainter {
  static func drawNebula(_ context: inout GraphicsContext, size: CGSize, time: TimeInterval, opacity: Double) {
    context.drawLayer { layer in
      layer.blendMode = .plusLighter
      for blob in OnboardingAmbientBlob.all {
        let center = blob.center(in: size, time: time)
        let rect = CGRect(
          x: center.x - blob.radius,
          y: center.y - blob.radius,
          width: blob.radius * 2,
          height: blob.radius * 2
        )
        let gradient = Gradient(colors: [
          blob.color.opacity(blob.alpha * opacity),
          blob.color.opacity(blob.alpha * 0.35 * opacity),
          .clear,
        ])
        layer.fill(
          Path(ellipseIn: rect),
          with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: blob.radius)
        )
      }
    }
  }

  /// Sixty-odd points, barely there. They drift upward with a little parallax
  /// and twinkle slowly. Under Reduce Motion they hold still.
  static func drawStars(
    _ context: inout GraphicsContext,
    size: CGSize,
    time: TimeInterval,
    drift: Bool,
    opacity: Double
  ) {
    var random = OnboardingStarRandom(seed: 0x5048_4f4e)
    for _ in 0 ..< 64 {
      let x = CGFloat(random.next()) * size.width
      var y = CGFloat(random.next()) * size.height
      let radius = 0.5 + CGFloat(random.next()) * 0.9
      let base = 0.06 + random.next() * 0.16
      let phase = random.next() * .pi * 2
      let rate = 0.3 + random.next() * 0.5
      let depth = 0.4 + CGFloat(random.next()) * 0.6
      var twinkle = 1.0
      if drift {
        y -= CGFloat(time) * OnboardingTiming.starDrift * depth
        y = y.truncatingRemainder(dividingBy: size.height)
        if y < 0 {
          y += size.height
        }
        twinkle = 0.7 + 0.3 * sin(time * rate + phase)
      }
      let rect = CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)
      context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(base * twinkle * opacity)))
    }
  }
}

struct OnboardingStarRandom {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed == 0 ? 0x9e37_79b9_7f4a_7c15 : seed
  }

  mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    let mixed = state ^ (state >> 30)
    return Double(mixed % 10000) / 10000
  }
}

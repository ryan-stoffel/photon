import SwiftUI

enum OnboardingColor {
  static let void = Color.black
  static let lift = Color(red: 0.04, green: 0.07, blue: 0.14)
  static let beam = Color(red: 0.45, green: 0.74, blue: 1)
  static let secondary = Color.white.opacity(0.72)
}

/// Near-black field inside the onboarding window. It stays put while steps change.
struct OnboardingBackdrop: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: model.instant)) { context in
      let atmosphere = atmosphere(at: context.date)
      ZStack {
        OnboardingColor.void
        LinearGradient(
          colors: [OnboardingColor.void, OnboardingColor.void, OnboardingColor.lift],
          startPoint: .top,
          endPoint: .bottom
        )
        .opacity(atmosphere)
        OnboardingStars(drift: atmosphere > 0.2 && !reduceMotion && !model.instant, date: context.date)
          .opacity(atmosphere * 0.9)
      }
    }
    .ignoresSafeArea()
  }

  private func atmosphere(at date: Date) -> Double {
    if model.instant || model.step != .reveal {
      return 1
    }
    let elapsed = date.timeIntervalSince(model.revealStarted)
    if reduceMotion {
      return min(1, elapsed / OnboardingTiming.reducedCrossfade)
    }
    if elapsed <= OnboardingTiming.decayStart {
      return 0
    }
    if elapsed >= OnboardingTiming.holdStart {
      return 1
    }
    return (elapsed - OnboardingTiming.decayStart) / OnboardingTiming.flashDecay
  }
}

/// Faint points. They stay still for a capture and drift only after the reveal in real use.
struct OnboardingStars: View {
  var drift: Bool
  var date: Date

  var body: some View {
    Canvas { context, size in
      let shift = drift ? CGFloat(date.timeIntervalSinceReferenceDate * 4) : 0
      var random = OnboardingStarRandom(seed: 0x5048_4f4e)
      for _ in 0 ..< 42 {
        let x = CGFloat(random.next()) * size.width
        var y = CGFloat(random.next()) * size.height + shift
        y = y.truncatingRemainder(dividingBy: size.height)
        if y < 0 {
          y += size.height
        }
        let radius = 0.4 + CGFloat(random.next()) * 0.9
        let alpha = 0.04 + Double(random.next()) * 0.1
        let rect = CGRect(x: x, y: y, width: radius, height: radius)
        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
      }
    }
    .allowsHitTesting(false)
    .ignoresSafeArea()
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

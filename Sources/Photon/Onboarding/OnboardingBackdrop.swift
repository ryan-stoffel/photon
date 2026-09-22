import SwiftUI

enum OnboardingColor {
  static let void = Color(red: 0.012, green: 0.016, blue: 0.03)
  static let lift = Color(red: 0.04, green: 0.07, blue: 0.14)
  static let beam = Color(red: 0.45, green: 0.74, blue: 1)
  static let secondary = Color.white.opacity(0.7)
}

/// Near-black field with a faint blue lift. It stays put while steps change.
struct OnboardingBackdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [OnboardingColor.void, OnboardingColor.void, OnboardingColor.lift],
        startPoint: .top,
        endPoint: .bottom
      )
      OnboardingStars()
    }
    .ignoresSafeArea()
  }
}

/// Faint, stable points. Positions come from a fixed seed so captures do not shimmer.
struct OnboardingStars: View {
  var body: some View {
    Canvas { context, size in
      var random = OnboardingStarRandom(seed: 0x5048_4f4e)
      for _ in 0 ..< 64 {
        let x = CGFloat(random.next()) * size.width
        let y = CGFloat(random.next()) * size.height
        let radius = 0.4 + CGFloat(random.next()) * 1.05
        let alpha = 0.05 + Double(random.next()) * 0.16
        let rect = CGRect(x: x, y: y, width: radius, height: radius)
        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
      }
    }
    .allowsHitTesting(false)
    .ignoresSafeArea()
  }
}

private struct OnboardingStarRandom {
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

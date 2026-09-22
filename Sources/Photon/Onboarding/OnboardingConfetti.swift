import SwiftUI

struct OnboardingConfettiView: View {
  var started: Date
  var reduceMotion: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
      let elapsed = context.date.timeIntervalSince(started)
      Canvas { context, size in
        let progress = min(1, elapsed / OnboardingTiming.confetti)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        for index in 0 ..< 16 {
          let angle = (Double(index) / 16) * Double.pi * 2 + 0.15
          let travel = reduceMotion ? 10.0 : 16 + 78 * progress
          let point = CGPoint(
            x: center.x + CGFloat(cos(angle) * travel),
            y: center.y + CGFloat(sin(angle) * travel) * 0.7
          )
          let alpha = (1 - progress) * 0.8
          let rect = CGRect(x: point.x, y: point.y, width: 3.5, height: 3.5)
          let color = index.isMultiple(of: 2)
            ? Color.white.opacity(alpha)
            : OnboardingColor.beam.opacity(alpha)
          context.fill(Path(ellipseIn: rect), with: .color(color))
        }
      }
    }
    .allowsHitTesting(false)
  }
}

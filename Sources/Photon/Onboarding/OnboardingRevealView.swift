import SwiftUI

struct OnboardingRevealView: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    ZStack {
      if model.instant {
        mark(scale: 1, glow: 0.4)
      } else {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
          let elapsed = context.date.timeIntervalSince(model.revealStarted)
          let clock = OnboardingRevealClock(time: elapsed, reduceMotion: reduceMotion)
          ZStack {
            if clock.showBeam {
              OnboardingBeam(progress: clock.beamProgress, collapse: clock.collapse)
            }
            flash(clock)
            mark(scale: clock.markScale, glow: clock.glow)
              .opacity(clock.markOpacity)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private func mark(scale: CGFloat, glow: Double) -> some View {
    VStack(spacing: 18) {
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 96, height: 96)
        .shadow(color: OnboardingColor.beam.opacity(glow), radius: 28)
      Text("Photon")
        .font(OnboardingFont.font(size: 44, weight: .medium))
        .foregroundStyle(.white)
    }
    .scaleEffect(scale)
  }

  private func flash(_ clock: OnboardingRevealClock) -> some View {
    Color.white
      .opacity(clock.flashOpacity)
      .ignoresSafeArea()
      .allowsHitTesting(false)
  }
}

struct OnboardingRevealClock {
  var time: TimeInterval
  var reduceMotion: Bool

  var beamProgress: CGFloat {
    guard !reduceMotion else {
      return 0
    }
    let span = (time - OnboardingTiming.revealBlack) / OnboardingTiming.beam
    return CGFloat(OnboardingTiming.easeInOut(span))
  }

  var showBeam: Bool {
    !reduceMotion && time >= OnboardingTiming.revealBlack && time < OnboardingTiming.flashStart + 0.12
  }

  /// 0 while the beam travels, 1 once it has pinched to a point.
  var collapse: CGFloat {
    guard time >= OnboardingTiming.flashStart else {
      return 0
    }
    return CGFloat(min(1, (time - OnboardingTiming.flashStart) / 0.08))
  }

  var flashOpacity: Double {
    guard !reduceMotion else {
      return 0
    }
    if time < OnboardingTiming.flashStart || time >= OnboardingTiming.holdStart {
      return 0
    }
    if time < OnboardingTiming.decayStart {
      return min(1, (time - OnboardingTiming.flashStart) / 0.06)
    }
    return 1 - (time - OnboardingTiming.decayStart) / OnboardingTiming.flashDecay
  }

  var markOpacity: Double {
    if reduceMotion {
      return min(1, time / OnboardingTiming.reducedCrossfade)
    }
    if time <= OnboardingTiming.decayStart {
      return 0
    }
    if time >= OnboardingTiming.holdStart {
      return 1
    }
    return (time - OnboardingTiming.decayStart) / OnboardingTiming.flashDecay
  }

  var markScale: CGFloat {
    0.9 + 0.1 * CGFloat(markOpacity)
  }

  var glow: Double {
    guard markOpacity > 0.05 else {
      return 0
    }
    let breathe = sin(time * 1.6) * 0.5 + 0.5
    return 0.22 + 0.2 * breathe
  }
}

private struct OnboardingBeam: View {
  var progress: CGFloat
  var collapse: CGFloat

  var body: some View {
    GeometryReader { geo in
      let travel = max(progress, 0.001)
      let head = geo.size.width * 0.5 * travel
      let trail = min(180, head) * (1 - collapse)
      let thickness = 2.0 * (1 - collapse)
      ZStack {
        LinearGradient(
          colors: [.clear, OnboardingColor.beam.opacity(0.08), OnboardingColor.beam.opacity(0.7), .white],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: max(trail, 1), height: max(thickness + 6, 1))
        .blur(radius: 8)
        .position(x: head - trail * 0.35, y: geo.size.height / 2)
        Capsule()
          .fill(Color.white)
          .frame(width: max(18 * (1 - collapse), 1), height: max(thickness, 0.4))
          .shadow(color: OnboardingColor.beam, radius: 14)
          .position(x: head, y: geo.size.height / 2)
      }
      .opacity(Double(1 - collapse * 0.85))
    }
    .allowsHitTesting(false)
  }
}

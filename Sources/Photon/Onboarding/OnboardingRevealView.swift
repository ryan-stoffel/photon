import SwiftUI

struct OnboardingRevealView: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    ZStack {
      if model.instant {
        mark.opacity(1)
      } else {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
          let elapsed = context.date.timeIntervalSince(model.revealStarted)
          let clock = OnboardingRevealClock(time: elapsed, reduceMotion: reduceMotion)
          ZStack {
            if clock.showBeam {
              OnboardingBeam(progress: clock.beamProgress)
            }
            Color.white
              .opacity(clock.flashOpacity)
              .ignoresSafeArea()
              .allowsHitTesting(false)
            mark.opacity(clock.markOpacity)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var mark: some View {
    VStack(spacing: 22) {
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 128, height: 128)
        .shadow(color: OnboardingColor.beam.opacity(0.45), radius: 28)
      Text("Photon")
        .font(OnboardingFont.font(size: 56, weight: .medium))
        .foregroundStyle(.white)
    }
  }
}

struct OnboardingRevealClock {
  var time: TimeInterval
  var reduceMotion: Bool

  var beamProgress: CGFloat {
    guard !reduceMotion else {
      return 0
    }
    return CGFloat(min(1, time / OnboardingTiming.beam))
  }

  var showBeam: Bool {
    !reduceMotion && time < OnboardingTiming.beam + 0.04
  }

  var flashOpacity: Double {
    guard !reduceMotion else {
      return 0
    }
    let fullUntil = OnboardingTiming.beam + OnboardingTiming.flash
    let fadedBy = fullUntil + OnboardingTiming.flashFade
    if time < OnboardingTiming.beam || time >= fadedBy {
      return 0
    }
    if time < fullUntil {
      return 1
    }
    return 1 - (time - fullUntil) / OnboardingTiming.flashFade
  }

  var markOpacity: Double {
    if reduceMotion {
      return min(1, time / OnboardingTiming.reducedCrossfade)
    }
    let start = OnboardingTiming.beam + OnboardingTiming.flash
    let end = start + OnboardingTiming.flashFade
    if time <= start {
      return 0
    }
    if time >= end {
      return 1
    }
    return (time - start) / OnboardingTiming.flashFade
  }
}

private struct OnboardingBeam: View {
  var progress: CGFloat

  var body: some View {
    GeometryReader { geo in
      let head = geo.size.width * 0.5 * max(progress, 0.02)
      let trail = min(260, head)
      ZStack {
        LinearGradient(
          colors: [.clear, OnboardingColor.beam.opacity(0.05), OnboardingColor.beam.opacity(0.85), .white],
          startPoint: .leading,
          endPoint: .trailing
        )
        .frame(width: trail, height: 3)
        .blur(radius: 7)
        .position(x: head - trail * 0.28, y: geo.size.height / 2)
        Capsule()
          .fill(Color.white)
          .frame(width: 28, height: 2)
          .shadow(color: OnboardingColor.beam, radius: 16)
          .position(x: head, y: geo.size.height / 2)
      }
    }
    .allowsHitTesting(false)
    .ignoresSafeArea()
  }
}

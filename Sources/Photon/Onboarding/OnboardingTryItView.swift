import SwiftUI

struct OnboardingTryItView: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    VStack(spacing: 26) {
      Spacer()
      icon
      Text("Press it to open Photon.")
        .font(OnboardingFont.font(size: 18, weight: .regular))
        .foregroundStyle(OnboardingColor.secondary)
      keycaps
      Spacer()
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var icon: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
      let bob = bobOffset(at: context.date)
      let glow = 0.28 + (reduceMotion ? 0 : abs(bob) / OnboardingTiming.bobDistance * 0.2)
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 88, height: 88)
        .shadow(color: OnboardingColor.beam.opacity(glow), radius: 26)
        .offset(y: bob)
    }
  }

  private var keycaps: some View {
    HStack(spacing: 12) {
      ForEach(Array(model.hotkey.keycapLabels.enumerated()), id: \.offset) { _, label in
        OnboardingKeycap(label: label)
      }
    }
  }

  private func bobOffset(at date: Date) -> CGFloat {
    guard !reduceMotion else {
      return 0
    }
    let turns = date.timeIntervalSinceReferenceDate / OnboardingTiming.bobPeriod
    return CGFloat(sin(turns * .pi * 2)) * OnboardingTiming.bobDistance
  }
}

private struct OnboardingKeycap: View {
  var label: String

  var body: some View {
    Text(label)
      .font(OnboardingFont.font(size: 20, weight: .medium))
      .foregroundStyle(.white)
      .frame(minWidth: 72, minHeight: 56)
      .padding(.horizontal, 10)
      .background(keyFace)
      .overlay(innerShade)
  }

  private var keyFace: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .fill(
        LinearGradient(
          colors: [
            Color.white.opacity(0.2),
            Color.white.opacity(0.07),
            Color.white.opacity(0.04),
          ],
          startPoint: .top,
          endPoint: .bottom
        )
      )
  }

  private var innerShade: some View {
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .stroke(Color.black.opacity(0.45), lineWidth: 4)
      .blur(radius: 2)
      .offset(y: 1)
      .mask(RoundedRectangle(cornerRadius: 12, style: .continuous))
  }
}

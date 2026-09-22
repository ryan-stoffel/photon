import SwiftUI

struct OnboardingTryItView: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
      icon
      keycaps
        .padding(.top, 44)
      Text("Press it to open Photon.")
        .font(OnboardingFont.font(size: 17, weight: .regular))
        .foregroundStyle(OnboardingColor.secondary)
        .padding(.top, 24)
      Spacer()
      Text("Esc skips this step")
        .font(OnboardingFont.font(size: 12, weight: .regular))
        .foregroundStyle(Color.white.opacity(0.3))
        .padding(.bottom, 48)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Floats with a slow bob; the glow swells with the height of the bob.
  private var icon: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || model.instant)) { context in
      let bob = bobOffset(at: context.date)
      let glow = 0.26 + (reduceMotion ? 0 : (bob / OnboardingTiming.bobDistance + 1) / 2 * 0.16)
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 88, height: 88)
        .shadow(color: OnboardingColor.beam.opacity(glow), radius: 26)
        .shadow(color: OnboardingColor.beam.opacity(glow * 0.5), radius: 56)
        .offset(y: bob)
    }
    .frame(height: 100)
  }

  private var keycaps: some View {
    HStack(spacing: 10) {
      ForEach(Array(model.hotkey.keycapLabels.enumerated()), id: \.offset) { _, label in
        OnboardingKeycap(label: label, pressed: model.keysPressed)
      }
    }
  }

  private func bobOffset(at date: Date) -> CGFloat {
    guard !reduceMotion, !model.instant else {
      return 0
    }
    let turns = date.timeIntervalSinceReferenceDate / OnboardingTiming.bobPeriod
    return CGFloat(sin(turns * .pi * 2)) * OnboardingTiming.bobDistance
  }
}

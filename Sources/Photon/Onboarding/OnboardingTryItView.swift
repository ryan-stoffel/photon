import SwiftUI

struct OnboardingTryItView: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    VStack(spacing: 28) {
      Spacer()
      icon
      Text("Press it to open Photon.")
        .font(OnboardingFont.font(size: 22, weight: .regular))
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
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 112, height: 112)
        .shadow(color: OnboardingColor.beam.opacity(0.55), radius: 32)
        .offset(y: bob)
    }
  }

  private var keycaps: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
      HStack(spacing: 12) {
        ForEach(Array(model.hotkey.keycapLabels.enumerated()), id: \.offset) { index, label in
          Text(label)
            .font(OnboardingFont.font(size: 22, weight: .medium))
            .foregroundStyle(.white)
            .frame(minWidth: 76, minHeight: 64)
            .padding(.horizontal, 8)
            .background(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .shadow(color: OnboardingColor.beam.opacity(0.28), radius: 18, y: 10)
            )
            .overlay(
              RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            )
            .offset(y: floatOffset(at: context.date, index: index))
        }
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

  private func floatOffset(at date: Date, index: Int) -> CGFloat {
    guard !reduceMotion else {
      return 0
    }
    let wave = date.timeIntervalSinceReferenceDate * 1.3 + Double(index) * 0.6
    return CGFloat(sin(wave)) * 3
  }
}

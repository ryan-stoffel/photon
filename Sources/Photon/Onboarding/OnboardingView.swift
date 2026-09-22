import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: OnboardingController

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      copy
        .padding(.top, 22)
      OnboardingStage(model: model)
        .padding(.top, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      footer
    }
    .padding(.horizontal, 32)
    .padding(.top, 26)
    .padding(.bottom, 22)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 28, height: 28)
      Text("Photon")
        .font(.system(size: 14, weight: .medium))
      Spacer()
      Button("Skip") {
        model.finish()
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
    }
  }

  private var copy: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let kicker = model.step.kicker {
        Text(kicker)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .textCase(.uppercase)
          .tracking(0.6)
      }
      Text(model.step.title)
        .font(.system(size: 32, weight: .medium))
      Text(model.step.body)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 460, alignment: .leading)
    }
    .id(model.step)
    .transition(.opacity)
  }

  private var footer: some View {
    HStack(spacing: 12) {
      if model.step != .welcome {
        Button("Back") {
          model.retreat()
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
      }
      Spacer()
      HStack(spacing: 6) {
        ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
          Capsule()
            .fill(Color.primary.opacity(step == model.step ? 0.85 : 0.18))
            .frame(width: step == model.step ? 16 : 6, height: 6)
        }
      }
      Spacer()
      continueButton
    }
  }

  private var continueButton: some View {
    Button(model.step.continues) {
      model.advance()
    }
    .buttonStyle(.borderedProminent)
    .keyboardShortcut(continueShortcut)
  }

  private var continueShortcut: KeyboardShortcut? {
    model.step.practice != .clipboard && model.step != .notes ? .defaultAction : nil
  }
}

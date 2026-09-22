import SwiftUI

struct OnboardingPermissionView: View {
  @ObservedObject var model: OnboardingController
  var kind: OnboardingPermission

  var body: some View {
    OnboardingStepLayout(symbol: kind.symbol, title: kind.title, message: kind.reason) {
      ZStack {
        if let notice = model.permissionNotice {
          Text(notice)
            .font(OnboardingFont.font(size: 15, weight: .regular))
            .foregroundStyle(.white.opacity(0.86))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 440)
            .transition(.opacity)
        } else {
          actions
            .transition(.opacity)
        }
      }
      .frame(minHeight: 112, alignment: .top)
    }
  }

  private var actions: some View {
    VStack(spacing: 14) {
      OnboardingPrimaryButton(
        title: model.permissionWaiting ? "Waiting…" : "Grant Access",
        disabled: model.permissionWaiting
      ) {
        model.grantPermission()
      }
      OnboardingTextButton(title: "Skip for now") {
        model.skipPermission()
      }
      .padding(.top, 4)
      Text(kind.skipNote)
        .font(OnboardingFont.font(size: 12, weight: .regular))
        .foregroundStyle(OnboardingColor.tertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
    }
  }
}

import SwiftUI

struct OnboardingPermissionView: View {
  @ObservedObject var model: OnboardingController
  var kind: OnboardingPermission

  var body: some View {
    VStack(spacing: 18) {
      Spacer()
      Text(kind.title)
        .font(OnboardingFont.font(size: 36, weight: .medium))
        .foregroundStyle(.white)
      Text(kind.reason)
        .font(OnboardingFont.font(size: 16, weight: .regular))
        .foregroundStyle(OnboardingColor.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
      noticeOrActions
        .padding(.top, 28)
      Spacer()
      Spacer()
    }
    .padding(.horizontal, 64)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var noticeOrActions: some View {
    if let notice = model.permissionNotice {
      Text(notice)
        .font(OnboardingFont.font(size: 15, weight: .regular))
        .foregroundStyle(.white.opacity(0.86))
        .multilineTextAlignment(.center)
        .frame(maxWidth: 420)
    } else {
      VStack(spacing: 16) {
        Button(action: { model.grantPermission() }, label: {
          Text(model.permissionWaiting ? "Waiting…" : "Grant")
            .font(OnboardingFont.font(size: 16, weight: .medium))
            .foregroundStyle(Color.black.opacity(0.88))
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.white))
        })
        .buttonStyle(.plain)
        .disabled(model.permissionWaiting)
        Button("Skip for now") {
          model.skipPermission()
        }
        .buttonStyle(.plain)
        .font(OnboardingFont.font(size: 13, weight: .regular))
        .foregroundStyle(Color.white.opacity(0.42))
      }
    }
  }
}

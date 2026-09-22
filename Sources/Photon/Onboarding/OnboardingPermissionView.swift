import SwiftUI

struct OnboardingPermissionView: View {
  @ObservedObject var model: OnboardingController
  var kind: OnboardingPermission

  var body: some View {
    VStack(spacing: 22) {
      Spacer()
      Text(kind.title)
        .font(OnboardingFont.font(size: 44, weight: .medium))
        .foregroundStyle(.white)
      Text(kind.reason)
        .font(OnboardingFont.font(size: 18, weight: .regular))
        .foregroundStyle(OnboardingColor.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 520)
      noticeOrActions
        .padding(.top, 12)
      Spacer()
      Spacer()
    }
    .padding(.horizontal, 48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var noticeOrActions: some View {
    if let notice = model.permissionNotice {
      Text(notice)
        .font(OnboardingFont.font(size: 16, weight: .regular))
        .foregroundStyle(.white)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 460)
    } else {
      VStack(spacing: 18) {
        Button(action: { model.grantPermission() }, label: {
          Text(model.permissionWaiting ? "Waiting…" : "Grant")
            .font(OnboardingFont.font(size: 20, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
              Rectangle()
                .fill(OnboardingColor.beam.opacity(0.9))
                .frame(height: 1)
            }
        })
        .buttonStyle(.plain)
        .disabled(model.permissionWaiting)
        Button("Skip for now") {
          model.skipPermission()
        }
        .buttonStyle(.plain)
        .font(OnboardingFont.font(size: 14, weight: .regular))
        .foregroundStyle(Color.white.opacity(0.45))
      }
    }
  }
}

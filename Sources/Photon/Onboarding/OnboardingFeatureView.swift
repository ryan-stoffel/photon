import SwiftUI

struct OnboardingFeatureView: View {
  var kind: OnboardingFeature

  var body: some View {
    VStack(spacing: 16) {
      Spacer()
      Text(kind.title)
        .font(OnboardingFont.font(size: 36, weight: .medium))
        .foregroundStyle(.white)
      Text(kind.body)
        .font(OnboardingFont.font(size: 16, weight: .regular))
        .foregroundStyle(OnboardingColor.secondary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: 440)
      Spacer()
      Spacer()
    }
    .padding(.horizontal, 64)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

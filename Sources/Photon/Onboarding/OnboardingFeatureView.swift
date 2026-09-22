import SwiftUI

struct OnboardingFeatureView: View {
  @ObservedObject var model: OnboardingController
  var kind: OnboardingFeature

  var body: some View {
    OnboardingStepLayout(symbol: kind.symbol, title: kind.title, message: kind.body) {
      OnboardingPrimaryButton(title: "Continue") {
        model.advance()
      }
    }
  }
}

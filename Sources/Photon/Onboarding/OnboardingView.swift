import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: OnboardingController
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      OnboardingBackdrop()
      if !model.step.isPermission, model.step != .tryIt {
        Color.clear
          .contentShape(Rectangle())
          .onTapGesture {
            model.advanceFromPointer()
          }
      }
      step
        .id(model.step.token)
        .transition(transition)
        .allowsHitTesting(model.step.isPermission)
    }
    .animation(motion, value: model.step.token)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var step: some View {
    switch model.step {
    case .reveal:
      OnboardingRevealView(model: model, reduceMotion: reduceMotion)
    case let .permission(kind):
      OnboardingPermissionView(model: model, kind: kind)
    case let .feature(kind):
      OnboardingFeatureView(kind: kind, reduceMotion: reduceMotion)
    case .tryIt:
      OnboardingTryItView(model: model, reduceMotion: reduceMotion)
    }
  }

  private var transition: AnyTransition {
    if reduceMotion || model.instant {
      return .opacity
    }
    return .asymmetric(
      insertion: .opacity.combined(with: .offset(y: OnboardingTiming.contentSlide)),
      removal: .opacity.combined(with: .offset(y: -12))
    )
  }

  private var motion: Animation? {
    model.instant ? nil : .easeInOut(duration: OnboardingTiming.content)
  }
}

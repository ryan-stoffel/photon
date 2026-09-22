import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: OnboardingController
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      OnboardingBackdrop(model: model, reduceMotion: reduceMotion)
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
      if let started = model.burstStarted {
        OnboardingBurstView(started: started)
      }
    }
    .animation(motion, value: model.step.token)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .clipShape(RoundedRectangle(cornerRadius: OnboardingChrome.cornerRadius, style: .continuous))
  }

  @ViewBuilder
  private var step: some View {
    switch model.step {
    case .reveal:
      OnboardingRevealView(model: model, reduceMotion: reduceMotion)
    case let .permission(kind):
      OnboardingPermissionView(model: model, kind: kind)
    case let .feature(kind):
      OnboardingFeatureView(kind: kind)
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
      removal: .opacity.combined(with: .offset(y: -OnboardingTiming.contentSlide))
    )
  }

  private var motion: Animation? {
    guard !model.instant else {
      return nil
    }
    return .spring(response: OnboardingTiming.content, dampingFraction: 0.86)
  }
}

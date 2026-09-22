import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: OnboardingController
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    ZStack {
      OnboardingBackdrop(model: model, reduceMotion: reduceMotion)
      step
        .id(model.step.token)
        .transition(transition)
      if model.step != .reveal {
        OnboardingProgressDots(step: model.step)
          .transition(.opacity)
      }
      if let started = model.confettiStarted {
        OnboardingConfettiView(started: started, reduceMotion: reduceMotion)
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
      OnboardingFeatureView(model: model, kind: kind)
    case .tryIt:
      OnboardingTryItView(model: model, reduceMotion: reduceMotion)
    }
  }

  /// Crossfade plus a 24 pt horizontal slide. Reduce Motion keeps the crossfade only.
  private var transition: AnyTransition {
    if reduceMotion || model.instant {
      return .opacity
    }
    return .asymmetric(
      insertion: .opacity.combined(with: .offset(x: OnboardingTiming.stepSlide)),
      removal: .opacity.combined(with: .offset(x: -OnboardingTiming.stepSlide))
    )
  }

  private var motion: Animation? {
    guard !model.instant else {
      return nil
    }
    return .spring(response: OnboardingTiming.stepResponse, dampingFraction: OnboardingTiming.stepDamping)
  }
}

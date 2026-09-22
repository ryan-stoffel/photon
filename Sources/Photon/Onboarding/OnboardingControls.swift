import SwiftUI

/// One glyph, one headline, one line of body text, and the actions under it.
/// Content sits a little above center, the way Raycast and Dia place theirs.
struct OnboardingStepLayout<Actions: View>: View {
  var symbol: String
  var title: String
  var message: String
  @ViewBuilder var actions: () -> Actions

  var body: some View {
    VStack(spacing: 0) {
      Spacer()
      Image(systemName: symbol)
        .font(.system(size: 30, weight: .light))
        .foregroundStyle(OnboardingColor.beam)
        .shadow(color: OnboardingColor.beam.opacity(0.55), radius: 18)
        .frame(height: 40)
      Text(title)
        .font(OnboardingFont.font(size: 34, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.top, 24)
      Text(message)
        .font(OnboardingFont.font(size: 16, weight: .regular))
        .foregroundStyle(OnboardingColor.secondary)
        .multilineTextAlignment(.center)
        .lineSpacing(4)
        .frame(maxWidth: 460)
        .padding(.top, 14)
      actions()
        .padding(.top, 40)
      Spacer()
      Spacer()
        .frame(height: 48)
    }
    .padding(.horizontal, 72)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct OnboardingPrimaryButton: View {
  var title: String
  var disabled = false
  var action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action, label: {
      Text(title)
        .font(OnboardingFont.font(size: 15, weight: .medium))
        .foregroundStyle(Color.black.opacity(0.88))
        .padding(.horizontal, 30)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color.white.opacity(hovering && !disabled ? 1 : 0.92)))
    })
    .buttonStyle(.plain)
    .disabled(disabled)
    .opacity(disabled ? 0.6 : 1)
    .onHover { inside in
      hovering = inside
    }
    .animation(.easeOut(duration: 0.15), value: hovering)
  }
}

struct OnboardingTextButton: View {
  var title: String
  var action: () -> Void

  @State private var hovering = false

  var body: some View {
    Button(action: action, label: {
      Text(title)
        .font(OnboardingFont.font(size: 13, weight: .regular))
        .foregroundStyle(Color.white.opacity(hovering ? 0.8 : 0.5))
    })
    .buttonStyle(.plain)
    .onHover { inside in
      hovering = inside
    }
    .animation(.easeOut(duration: 0.15), value: hovering)
  }
}

/// Small dots along the bottom for every step after the reveal.
struct OnboardingProgressDots: View {
  var step: OnboardingStep

  var body: some View {
    if let index = step.progressIndex {
      HStack(spacing: 8) {
        ForEach(0 ..< OnboardingStep.progressCount, id: \.self) { position in
          Circle()
            .fill(Color.white.opacity(position == index ? 0.85 : 0.18))
            .frame(width: 5, height: 5)
        }
      }
      .frame(maxHeight: .infinity, alignment: .bottom)
      .padding(.bottom, 26)
      .animation(.easeInOut(duration: 0.3), value: index)
      .allowsHitTesting(false)
    }
  }
}

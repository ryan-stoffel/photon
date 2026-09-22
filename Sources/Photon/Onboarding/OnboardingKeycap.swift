import SwiftUI

/// A physical-looking key: rounded face with a slight gradient, a light top
/// edge, a darker lip underneath, and a soft drop shadow. Pressing sinks it.
struct OnboardingKeycap: View {
  var label: String
  var pressed: Bool

  private static let radius: CGFloat = 12
  private static let height: CGFloat = 60

  var body: some View {
    ZStack {
      lip
        .offset(y: pressed ? 1 : 3)
      face
        .overlay(content)
        .offset(y: pressed ? 2 : 0)
    }
    .frame(width: width, height: Self.height)
    .shadow(color: .black.opacity(0.45), radius: 10, y: 6)
    .animation(.easeOut(duration: 0.08), value: pressed)
  }

  private var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: Self.radius, style: .continuous)
  }

  private var lip: some View {
    shape.fill(Color(white: 0.06))
  }

  private var face: some View {
    shape
      .fill(
        LinearGradient(
          colors: [Color(white: 0.21), Color(white: 0.13)],
          startPoint: .top,
          endPoint: .bottom
        )
      )
      .overlay(
        shape
          .inset(by: 0.5)
          .stroke(
            LinearGradient(
              colors: [Color.white.opacity(0.16), Color.white.opacity(0.03)],
              startPoint: .top,
              endPoint: .bottom
            ),
            lineWidth: 1
          )
      )
      .overlay(
        shape
          .stroke(Color.black.opacity(0.5), lineWidth: 3)
          .blur(radius: 3)
          .offset(y: 2)
          .mask { shape }
      )
      .overlay(shape.stroke(Color.black.opacity(0.6), lineWidth: 1))
  }

  @ViewBuilder
  private var content: some View {
    if let name = modifierName {
      VStack(spacing: 2) {
        Text(label)
          .font(OnboardingFont.font(size: 24, weight: .medium))
          .foregroundStyle(.white.opacity(0.92))
        Text(name)
          .font(OnboardingFont.font(size: 10, weight: .regular))
          .foregroundStyle(.white.opacity(0.42))
      }
    } else {
      Text(label)
        .font(OnboardingFont.font(size: 16, weight: .medium))
        .foregroundStyle(.white.opacity(0.92))
    }
  }

  private var width: CGFloat {
    if modifierName != nil {
      return 64
    }
    if label == "Space" {
      return 168
    }
    return max(64, CGFloat(label.count) * 11 + 30)
  }

  private var modifierName: String? {
    switch label {
    case "⌘": "command"
    case "⌥": "option"
    case "⌃": "control"
    case "⇧": "shift"
    default: nil
    }
  }
}

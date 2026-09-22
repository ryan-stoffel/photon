import SwiftUI

struct OnboardingFeatureView: View {
  var kind: OnboardingFeature
  var reduceMotion: Bool

  var body: some View {
    VStack(spacing: 36) {
      Spacer()
      OnboardingFeaturePreview(kind: kind, reduceMotion: reduceMotion)
        .frame(height: 132)
      VStack(spacing: 14) {
        Text(kind.title)
          .font(OnboardingFont.font(size: 44, weight: .medium))
          .foregroundStyle(.white)
        Text(kind.body)
          .font(OnboardingFont.font(size: 18, weight: .regular))
          .foregroundStyle(OnboardingColor.secondary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: 480)
      }
      Spacer()
      Spacer()
    }
    .padding(.horizontal, 48)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct OnboardingFeaturePreview: View {
  var kind: OnboardingFeature
  var reduceMotion: Bool

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
      let phase = reduceMotion ? 0.35 : (sin(context.date.timeIntervalSinceReferenceDate * 1.4) + 1) / 2
      preview(phase: phase)
    }
  }

  @ViewBuilder
  private func preview(phase: Double) -> some View {
    switch kind {
    case .search:
      searchPreview(phase: phase)
    case .suggestions:
      suggestionPreview
    case .clipboard:
      labeledRows(["Launch plan", "A link you copied", "A screenshot"])
    case .notes:
      Text("Today\nShip the sequence.")
        .font(OnboardingFont.font(size: 18, weight: .regular))
        .foregroundStyle(Color.white.opacity(0.82))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 80)
    case .files:
      labeledRows(["Ember pitch", "Documents"])
    case .settings:
      HStack(spacing: 10) {
        keycap("⌘", phase: phase)
        keycap(",", phase: phase)
      }
    }
  }

  private func searchPreview(phase: Double) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 8) {
        Text("sa")
          .font(OnboardingFont.font(size: 22, weight: .medium))
          .foregroundStyle(.white)
        Rectangle()
          .fill(Color.white.opacity(phase > 0.5 ? 0.9 : 0.2))
          .frame(width: 1.5, height: 22)
        Spacer()
      }
      labeledRows(["Safari", "Notes", "Files"])
    }
    .padding(.horizontal, 80)
  }

  private var suggestionPreview: some View {
    VStack(alignment: .leading, spacing: 8) {
      previewRow("Safari", detail: "Most opened", dot: false)
      previewRow("Mail", detail: "Opened often", dot: true)
      previewRow("Notes", detail: "Still an app", dot: false)
    }
    .padding(.horizontal, 80)
  }

  private func labeledRows(_ titles: [String]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(titles, id: \.self) { title in
        previewRow(title, detail: "", dot: false)
      }
    }
  }

  private func previewRow(_ title: String, detail: String, dot: Bool) -> some View {
    HStack(spacing: 10) {
      Circle()
        .fill(Color.white.opacity(dot ? 0.9 : 0.28))
        .frame(width: dot ? 5 : 8, height: dot ? 5 : 8)
      Text(title)
        .font(OnboardingFont.font(size: 16, weight: .medium))
        .foregroundStyle(.white)
      if !detail.isEmpty {
        Text(detail)
          .font(OnboardingFont.font(size: 13, weight: .regular))
          .foregroundStyle(OnboardingColor.secondary)
      }
      Spacer(minLength: 0)
    }
  }

  private func keycap(_ label: String, phase: Double) -> some View {
    Text(label)
      .font(OnboardingFont.font(size: 22, weight: .medium))
      .foregroundStyle(.white)
      .frame(width: 64, height: 52)
      .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .fill(Color.white.opacity(0.06))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
          .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
      )
      .offset(y: CGFloat(phase - 0.5) * 4)
  }
}

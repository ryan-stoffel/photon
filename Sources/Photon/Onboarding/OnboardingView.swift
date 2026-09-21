import SwiftUI

struct OnboardingView: View {
  @ObservedObject var model: OnboardingController

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      header
      Spacer(minLength: 12)
      copy
      visual
        .padding(.top, 22)
      Spacer(minLength: 16)
      footer
    }
    .padding(.horizontal, 28)
    .padding(.top, 28)
    .padding(.bottom, 22)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }

  private var header: some View {
    HStack(spacing: 10) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .interpolation(.high)
        .frame(width: 28, height: 28)
      Text("Photon")
        .font(.system(size: 14, weight: .medium))
      Spacer()
      Text("\(model.step.rawValue + 1) of \(OnboardingStep.allCases.count)")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .monospacedDigit()
    }
  }

  private var copy: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let kicker = model.step.kicker {
        Text(kicker)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      Text(model.step.title)
        .font(.system(size: 28, weight: .medium))
      Text(model.step.body)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 420, alignment: .leading)
    }
  }

  @ViewBuilder
  private var visual: some View {
    switch model.step {
    case .welcome:
      EmptyView()
    case .launcher:
      keycaps
    case .suggestions:
      suggestionPreview
    case .search:
      libraryRows
    case .settings:
      settingsHint
    }
  }

  private var keycaps: some View {
    HStack(spacing: 8) {
      ForEach(Array(model.hotkey.keycapLabels.enumerated()), id: \.offset) { _, label in
        Text(label)
          .font(.system(size: 22, weight: .medium, design: .rounded))
          .frame(minWidth: 44, minHeight: 44)
          .padding(.horizontal, 8)
          .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .fill(Color.primary.opacity(0.08))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
              .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
          )
      }
      Spacer(minLength: 0)
    }
  }

  private var suggestionPreview: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Suggestions")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
      previewRow(symbol: "app.fill", title: "Most opened", detail: "Highest use count", dot: false)
      previewRow(symbol: "app.fill", title: "Opened often", detail: "Still an app", dot: true)
    }
    .padding(.vertical, 8)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.primary.opacity(0.05))
    )
  }

  private var libraryRows: some View {
    VStack(alignment: .leading, spacing: 0) {
      previewRow(symbol: "clipboard", title: "Clipboard", detail: "Recent copies, ready to paste", dot: false)
      previewRow(symbol: "note.text", title: "Notes", detail: "Quick notes that stay searchable", dot: false)
      previewRow(symbol: "folder", title: "Files", detail: "Find something in your home folder", dot: false)
    }
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.primary.opacity(0.05))
    )
  }

  private var settingsHint: some View {
    HStack(spacing: 8) {
      Text("⌘")
      Text(",")
    }
    .font(.system(size: 22, weight: .medium, design: .rounded))
    .padding(.horizontal, 4)
  }

  private func previewRow(symbol: String, title: String, detail: String, dot: Bool) -> some View {
    HStack(spacing: 12) {
      ZStack(alignment: .bottom) {
        Image(systemName: symbol)
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 28)
          .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
              .fill(Color.primary.opacity(0.08))
          )
        if dot {
          Circle()
            .fill(Color.primary.opacity(0.78))
            .frame(width: 4, height: 4)
            .offset(y: 3)
        }
      }
      .frame(width: 28, height: 28)
      Text(title)
        .font(.system(size: 14, weight: .medium))
      Text(detail)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .frame(height: 40)
  }

  private var footer: some View {
    HStack(spacing: 12) {
      Button("Skip") {
        model.finish()
      }
      .buttonStyle(.borderless)
      .foregroundStyle(.secondary)
      Spacer()
      HStack(spacing: 6) {
        ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
          Circle()
            .fill(Color.primary.opacity(step == model.step ? 0.85 : 0.2))
            .frame(width: 6, height: 6)
        }
      }
      Spacer()
      Button(model.step.continues) {
        model.advance()
      }
      .buttonStyle(.borderedProminent)
      .keyboardShortcut(.defaultAction)
    }
  }
}

import SwiftUI

struct OnboardingStage: View {
  @ObservedObject var model: OnboardingController

  var body: some View {
    ZStack(alignment: .topLeading) {
      RoundedRectangle(cornerRadius: 16, style: .continuous)
        .fill(Color.primary.opacity(0.045))
      stage
        .padding(16)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 248)
    .animation(.spring(response: 0.42, dampingFraction: 0.86), value: model.step)
  }

  @ViewBuilder
  private var stage: some View {
    switch model.step {
    case .welcome:
      welcome
    case .launcher:
      launcherKeys
    case .suggestions:
      suggestionRows
    case .search:
      searchPractice
    case .clipboard:
      clipboardPractice
    case .notes:
      notePractice
    case .files:
      filesPractice
    case .settings:
      settingsKeys
    }
  }

  private var welcome: some View {
    VStack(spacing: 14) {
      Spacer(minLength: 0)
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 88, height: 88)
        .shadow(color: .black.opacity(0.12), radius: 16, y: 8)
      Text("Press Continue, then try each step.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var launcherKeys: some View {
    VStack(alignment: .leading, spacing: 16) {
      keycaps(model.hotkey.keycapLabels, landed: model.shortcutLanded)
      Text(model.shortcutLanded ? "That opens Photon." : "Press the shortcut to try it.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
  }

  private var suggestionRows: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Suggestions")
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.bottom, 6)
      stageRow(symbol: "globe", title: "Safari", detail: "Most opened", dot: false)
      stageRow(symbol: "envelope", title: "Mail", detail: "Opened often", dot: true)
      stageRow(symbol: "note.text", title: "Notes", detail: "Still an app", dot: false)
      Spacer(minLength: 0)
    }
  }

  private var searchPractice: some View {
    VStack(alignment: .leading, spacing: 8) {
      practiceField("Try a few letters", text: $model.practiceQuery)
      let hits = searchHits.filter { hit in
        model.practiceQuery.isEmpty || hit.title.localizedCaseInsensitiveContains(model.practiceQuery)
      }
      if hits.isEmpty {
        Text("Nothing matches that yet.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
      } else {
        ForEach(hits) { hit in
          stageRow(symbol: hit.symbol, title: hit.title, detail: hit.detail, dot: false)
        }
      }
      Spacer(minLength: 0)
    }
  }

  private var clipboardPractice: some View {
    VStack(alignment: .leading, spacing: 0) {
      stageRow(
        symbol: model.clipboardPasted ? "checkmark.circle.fill" : "doc.on.clipboard",
        title: "Launch plan",
        detail: model.clipboardPasted ? "Pasted" : "Press Return",
        dot: false
      )
      stageRow(symbol: "link", title: "A link you copied", detail: "Earlier today", dot: false)
      stageRow(symbol: "photo", title: "A screenshot", detail: "Image", dot: false)
      Spacer(minLength: 0)
    }
  }

  private var notePractice: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Today")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.secondary)
      TextField("Write a line", text: $model.noteDraft, axis: .vertical)
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .lineLimit(3, reservesSpace: true)
        .focused($practiceFocus)
      Spacer(minLength: 0)
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(Color.primary.opacity(0.04))
    )
  }

  private var filesPractice: some View {
    VStack(alignment: .leading, spacing: 8) {
      practiceField("ember", text: $model.practiceQuery)
      if showsEmber {
        stageRow(symbol: "doc.richtext", title: "Ember pitch", detail: "PDF in Documents", dot: false)
      } else {
        Text("Keep typing. ember finds the pitch.")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
      }
      Spacer(minLength: 0)
    }
  }

  private var settingsKeys: some View {
    VStack(alignment: .leading, spacing: 16) {
      keycaps(["⌘", ","], landed: model.shortcutLanded)
      Text(model.shortcutLanded ? "Settings is one shortcut away." : "Press ⌘, to try it.")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer(minLength: 0)
    }
  }

  private var showsEmber: Bool {
    let query = model.practiceQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    return query.isEmpty || "ember".hasPrefix(query.lowercased()) || "ember pitch".contains(query.lowercased())
  }

  private var searchHits: [OnboardingHit] {
    let catalog = [
      OnboardingHit(symbol: "globe", title: "Safari", detail: "Application"),
      OnboardingHit(symbol: "clipboard", title: "Clipboard", detail: "Recent copies"),
      OnboardingHit(symbol: "note.text", title: "Notes", detail: "Searchable notes"),
      OnboardingHit(symbol: "folder", title: "Files", detail: "Home folder"),
    ]
    let query = model.practiceQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else {
      return Array(catalog.dropFirst())
    }
    return catalog.filter { $0.title.localizedCaseInsensitiveContains(query) }
  }

  @FocusState private var practiceFocus: Bool

  private func practiceField(_ prompt: String, text: Binding<String>) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .foregroundStyle(.secondary)
      TextField(prompt, text: text)
        .textFieldStyle(.plain)
        .font(.system(size: 16))
        .focused($practiceFocus)
    }
    .padding(.horizontal, 12)
    .frame(height: 40)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.primary.opacity(0.06))
    )
    .onAppear {
      practiceFocus = true
    }
  }

  private func keycaps(_ labels: [String], landed: Bool) -> some View {
    HStack(spacing: 8) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
        Text(label)
          .font(.system(size: 22, weight: .medium, design: .rounded))
          .frame(minWidth: 56, minHeight: 52)
          .padding(.horizontal, 8)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(Color.primary.opacity(landed ? 0.16 : 0.08))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .strokeBorder(Color.primary.opacity(landed ? 0.28 : 0.1), lineWidth: 1)
          )
          .scaleEffect(landed ? 0.96 : 1)
      }
      Spacer(minLength: 0)
    }
    .padding(.top, 8)
  }

  private func stageRow(symbol: String, title: String, detail: String, dot: Bool) -> some View {
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
    .padding(.horizontal, 8)
    .frame(height: 36)
  }
}

private struct OnboardingHit: Identifiable {
  var symbol: String
  var title: String
  var detail: String

  var id: String {
    title
  }
}

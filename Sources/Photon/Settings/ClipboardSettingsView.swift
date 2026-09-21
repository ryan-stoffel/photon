import AppKit
import PhotonClipboard
import PhotonCore
import SwiftUI
import UniformTypeIdentifiers

struct ClipboardSettingsView: View {
  @EnvironmentObject private var settings: SettingsStore
  @EnvironmentObject private var clipboard: ClipboardManager

  @State private var newBundleID = ""
  @State private var isConfirmingClear = false

  var body: some View {
    PhotonSettingsPage(title: "Clipboard") {
      historySection
      pasteSection
      shortcutSection
      excludedAppsSection
      storageSection
    }
    .onAppear {
      clipboard.refreshAccessibility()
    }
    .confirmationDialog(
      "Clear clipboard history?",
      isPresented: $isConfirmingClear,
      titleVisibility: .visible
    ) {
      Button("Clear \(clipboard.items.count) Items", role: .destructive) {
        clipboard.clearAll()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This removes every item, including pinned ones. It cannot be undone.")
    }
  }

  private var historySection: some View {
    PhotonSettingsCard(
      title: "History",
      footer: "Pinned items never expire and do not count against the limit."
    ) {
      PhotonSettingsRow(title: "Save clipboard history") {
        Toggle("", isOn: $settings.clipboardEnabled)
          .toggleStyle(.switch)
          .labelsHidden()
      }
      PhotonSettingsRow(title: "Keep items for") {
        Picker("Keep items for", selection: $settings.clipboardRetention) {
          ForEach(ClipboardRetention.allCases) { retention in
            Text(retention.label).tag(retention)
          }
        }
        .labelsHidden()
        .disabled(!settings.clipboardEnabled)
        .frame(maxWidth: 180)
      }
      PhotonSettingsRow(title: "Maximum items") {
        Stepper(
          value: $settings.clipboardMaxItems,
          in: ClipboardSettings.maxItemsRange,
          step: 50
        ) {
          Text("\(settings.clipboardMaxItems)")
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .disabled(!settings.clipboardEnabled)
      }
    }
  }

  private var pasteSection: some View {
    PhotonSettingsCard(
      title: "Paste",
      footer: "Cmd+Return always copies without pasting."
    ) {
      PhotonSettingsRow(title: "Return key") {
        Picker("Return key", selection: $settings.clipboardPasteBehavior) {
          ForEach(ClipboardPasteBehavior.allCases) { behavior in
            Text(behavior.label).tag(behavior)
          }
        }
        .labelsHidden()
        .frame(maxWidth: 180)
      }
      if settings.clipboardPasteBehavior == .paste {
        accessibilityStatus
      }
    }
  }

  private var accessibilityStatus: some View {
    let trusted = clipboard.isAccessibilityTrusted
    return HStack(spacing: 8) {
      Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        .foregroundStyle(trusted ? .green : .orange)
      Text(
        trusted
          ? "Accessibility access granted. Photon can paste into the frontmost app."
          : "Pasting needs Accessibility access. Until it is granted, Return only copies."
      )
      .font(.system(size: 12))
      Spacer()
      if !trusted {
        Button("Open Accessibility Settings") {
          clipboard.requestAccessibility()
          clipboard.openAccessibilitySettings()
        }
        .buttonStyle(.borderless)
      }
    }
    .padding(.horizontal, 10)
    .padding(.bottom, 6)
  }

  private var shortcutSection: some View {
    PhotonSettingsCard(
      title: "Shortcut",
      footer: "You can also type \"cb\" or \"clipboard\" followed by a space in the launcher."
    ) {
      PhotonSettingsRow(title: "Open clipboard history with a shortcut") {
        Toggle("", isOn: $settings.clipboardHotkeyEnabled)
          .toggleStyle(.switch)
          .labelsHidden()
          .disabled(!settings.clipboardEnabled)
      }
      PhotonSettingsRow(title: "Shortcut") {
        HotkeyRecorder(combo: $settings.clipboardHotkey)
          .frame(width: 180, height: 24)
      }
    }
  }

  private var excludedAppsSection: some View {
    PhotonSettingsCard(
      title: "Excluded apps",
      footer: "Nothing copied while one of these apps is frontmost is recorded. "
        + "Password managers are excluded by default."
    ) {
      if settings.clipboardExcludedBundleIDs.isEmpty {
        PhotonSettingsCaption(text: "No excluded apps. Everything you copy is recorded.")
      }
      ForEach(settings.clipboardExcludedBundleIDs, id: \.self) { bundleID in
        HStack(spacing: 10) {
          Image(nsImage: AppIconCache.shared.icon(forBundleID: bundleID))
            .resizable()
            .frame(width: 20, height: 20)
          VStack(alignment: .leading, spacing: 1) {
            Text(AppIconCache.shared.appName(forBundleID: bundleID))
              .font(.system(size: 14, weight: .medium))
            Text(bundleID)
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
          Spacer()
          Button {
            removeExcluded(bundleID)
          } label: {
            Image(systemName: "minus.circle")
          }
          .buttonStyle(.borderless)
          .help("Remove")
        }
        .padding(.horizontal, 10)
        .frame(height: LauncherLayout.rowHeight)
      }
      HStack {
        TextField("Bundle identifier, e.g. com.example.app", text: $newBundleID)
          .textFieldStyle(.roundedBorder)
          .onSubmit(addTypedBundleID)
        Button("Add", action: addTypedBundleID)
          .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
        Button("Choose App…", action: chooseApp)
      }
      .padding(.horizontal, 10)
      .padding(.bottom, 6)
    }
  }

  private var storageSection: some View {
    PhotonSettingsCard(title: "Storage") {
      PhotonSettingsRow(title: "History") {
        Text("\(clipboard.items.count) items · \(formattedBytes(clipboard.storageBytes))")
          .foregroundStyle(.secondary)
          .monospacedDigit()
      }
      PhotonSettingsCaption(text: "Stored in ~/Library/Application Support/Photon/Clipboard")
      HStack {
        Spacer()
        Button("Clear History…", role: .destructive) {
          isConfirmingClear = true
        }
        .disabled(clipboard.items.isEmpty)
      }
      .padding(.horizontal, 10)
      .padding(.bottom, 6)
    }
  }

  private func addTypedBundleID() {
    let trimmed = newBundleID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return
    }
    addExcluded(trimmed)
    newBundleID = ""
  }

  private func addExcluded(_ bundleID: String) {
    let exists = settings.clipboardExcludedBundleIDs.contains {
      $0.caseInsensitiveCompare(bundleID) == .orderedSame
    }
    guard !exists else {
      return
    }
    settings.clipboardExcludedBundleIDs.append(bundleID)
  }

  private func removeExcluded(_ bundleID: String) {
    settings.clipboardExcludedBundleIDs.removeAll { $0 == bundleID }
  }

  private func chooseApp() {
    let panel = NSOpenPanel()
    panel.title = "Exclude an app from clipboard history"
    panel.prompt = "Exclude"
    panel.allowedContentTypes = [.applicationBundle]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.treatsFilePackagesAsDirectories = false
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    guard panel.runModal() == .OK else {
      return
    }
    for url in panel.urls {
      if let bundleID = Bundle(url: url)?.bundleIdentifier {
        addExcluded(bundleID)
      }
    }
  }

  private func formattedBytes(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
  }
}

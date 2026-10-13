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
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
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
      footer: "Pinned items never expire. They count toward the limit but are never removed."
    ) {
      PhotonSettingsRow(title: "Save clipboard history") {
        Toggle("", isOn: $settings.clipboardEnabled)
          .toggleStyle(.switch)
          .labelsHidden()
          .settingsFocused(.control("clipboard.enabled"))
      }
      PhotonSettingsRow(title: "Keep items for") {
        Picker("Keep items for", selection: $settings.clipboardRetention) {
          ForEach(ClipboardRetention.allCases) { retention in
            Text(retention.label).tag(retention)
          }
        }
        .labelsHidden()
        .disabled(!settings.clipboardEnabled)
        .settingsFocused(.control("clipboard.retention"))
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
        .settingsFocused(.control("clipboard.maxItems"))
      }
    }
  }

  private var pasteSection: some View {
    PhotonSettingsCard(
      title: "Paste",
      footer: "Return runs the primary action. Cmd+Return runs the other one."
    ) {
      PhotonSettingsRow(title: "Primary Action") {
        Picker("Primary Action", selection: $settings.clipboardPasteBehavior) {
          ForEach(ClipboardPasteBehavior.allCases) { behavior in
            Text(behavior.label).tag(behavior)
          }
        }
        .labelsHidden()
        .settingsFocused(.control("clipboard.pasteBehavior"))
        .frame(maxWidth: 180)
      }
      accessibilityStatus
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
          : "Pasting needs Accessibility access. Until it is granted, pasting only copies."
      )
      .font(.system(size: 12))
      Spacer()
      if !trusted {
        Button("Open Accessibility Settings") {
          clipboard.requestAccessibility()
          clipboard.openAccessibilitySettings()
        }
        .buttonStyle(.borderless)
        .settingsFocused(.control("clipboard.accessibility"))
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
          .settingsFocused(.control("clipboard.hotkeyEnabled"))
      }
      PhotonSettingsRow(title: "Shortcut") {
        HotkeyRecorder(combo: $settings.clipboardHotkey)
          .frame(width: 180, height: 24)
      }
      if let hotkeyClash {
        Text(hotkeyClash)
          .font(.system(size: 12))
          .foregroundStyle(.red)
          .padding(.horizontal, 10)
          .padding(.bottom, 6)
      }
    }
  }

  /// Carbon refuses a second registration of the same combo, so one of the two shortcuts would not work.
  private var hotkeyClash: String? {
    guard settings.clipboardEnabled, settings.clipboardHotkeyEnabled else {
      return nil
    }
    if settings.clipboardHotkey == settings.hotkey {
      return "The launcher already uses this shortcut."
    }
    if settings.clipboardHotkey == settings.notesHotkey {
      return "Notes already uses this shortcut."
    }
    return nil
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
          .settingsFocused(.control("clipboard.excludedField"))
        Button("Add", action: addTypedBundleID)
          .disabled(newBundleID.trimmingCharacters(in: .whitespaces).isEmpty)
          .settingsFocused(.control("clipboard.excludedAdd"))
        Button("Choose App…", action: chooseApp)
          .settingsFocused(.control("clipboard.chooseApp"))
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
      PhotonSettingsCaption(text: "Stored in \(Self.storagePath)")
      HStack {
        Spacer()
        Button("Clear History…", role: .destructive) {
          isConfirmingClear = true
        }
        .disabled(clipboard.items.isEmpty)
        .settingsFocused(.control("clipboard.clear"))
      }
      .padding(.horizontal, 10)
      .padding(.bottom, 6)
    }
  }

  /// The folder `AppRuntime` gives the clipboard store, with the home folder shown as ~.
  private static let storagePath = (AppRuntime.dataDirectory().appendingPathComponent("Clipboard").path as NSString)
    .abbreviatingWithTildeInPath

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

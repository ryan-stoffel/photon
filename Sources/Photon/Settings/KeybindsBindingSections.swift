import AppKit
import PhotonApps
import PhotonCore
import PhotonKeybinds
import SwiftUI
import UniformTypeIdentifiers

/// Installed and currently running apps, each with an optional shortcut.
struct AppHotkeysSection: View {
  @EnvironmentObject private var settings: SettingsStore
  @EnvironmentObject private var keybinds: KeybindsController
  @EnvironmentObject private var runningApps: RunningApplications
  @State private var installed: [AppHotkeyNamedApp] = []
  @State private var runningNamed: [AppHotkeyNamedApp] = []
  @State private var addError: String?
  @State private var filter = ""

  var body: some View {
    PhotonSettingsCard(
      title: "App hotkeys",
      footer: "The shortcut launches or focuses the app. Press it again while the app is frontmost to hide it."
    ) {
      HStack {
        TextField("Filter apps", text: $filter)
          .textFieldStyle(.plain)
          .font(.system(size: 14))
        Button("Add missing app…") {
          addApplication()
        }
        .buttonStyle(.borderless)
      }
      .padding(.horizontal, 10)
      .frame(height: LauncherLayout.rowHeight)
      if let addError {
        Text(addError)
          .font(.system(size: 12))
          .foregroundStyle(.red)
          .padding(.horizontal, 10)
      }

      PhotonSettingsHairline()

      if visibleRows.isEmpty {
        PhotonSettingsCaption(text: emptyText)
      } else {
        ForEach(visibleRows) { row in
          AppHotkeyCatalogRowView(
            row: row,
            shortcut: shortcutBinding(for: row),
            conflict: hasConflict(row),
            failure: shortcut(for: row).flatMap { keybinds.registrationFailures[$0] },
            onRemoveExtra: row.isExtra ? { removeExtra(row.bundleIdentifier) } : nil
          )
        }
      }
    }
    .onAppear(perform: reloadCatalog)
    .onChange(of: runningApps.bundleIdentifiers) { _, _ in
      reloadRunning()
    }
  }

  private var emptyText: String {
    filter.isEmpty
      ? "No applications found."
      : "No apps match “\(filter)”."
  }

  private var catalogRows: [AppHotkeyCatalogRow] {
    AppHotkeyCatalog.rows(
      installed: installed,
      running: runningNamed,
      saved: settings.keybinds.appHotkeys
    )
  }

  private var visibleRows: [AppHotkeyCatalogRow] {
    let trimmed = filter.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
      return catalogRows
    }
    return catalogRows.filter { row in
      row.name.localizedCaseInsensitiveContains(trimmed)
        || row.bundleIdentifier.localizedCaseInsensitiveContains(trimmed)
    }
  }

  private var conflicts: Set<BindingOwner> {
    settings.keybinds.conflictingOwners(launcher: KeyShortcut(settings.hotkey))
  }

  private func hasConflict(_ row: AppHotkeyCatalogRow) -> Bool {
    let owners = conflicts
    return settings.keybinds.appHotkeys.contains { hotkey in
      hotkey.bundleIdentifier.caseInsensitiveCompare(row.bundleIdentifier) == .orderedSame
        && owners.contains(.app(hotkey.id))
    }
  }

  private func shortcut(for row: AppHotkeyCatalogRow) -> KeyShortcut? {
    settings.keybinds.appHotkeys.first {
      $0.bundleIdentifier.caseInsensitiveCompare(row.bundleIdentifier) == .orderedSame
    }?.shortcut
  }

  private func shortcutBinding(for row: AppHotkeyCatalogRow) -> Binding<KeyShortcut?> {
    Binding(
      get: { shortcut(for: row) },
      set: { upsert(row, shortcut: $0) }
    )
  }

  private func upsert(_ row: AppHotkeyCatalogRow, shortcut: KeyShortcut?) {
    var keybinds = settings.keybinds
    if let index = keybinds.appHotkeys.firstIndex(where: {
      $0.bundleIdentifier.caseInsensitiveCompare(row.bundleIdentifier) == .orderedSame
    }) {
      if shortcut == nil, !row.isExtra {
        keybinds.appHotkeys.remove(at: index)
      } else {
        keybinds.appHotkeys[index].name = row.name
        keybinds.appHotkeys[index].shortcut = shortcut
      }
    } else if shortcut != nil || row.isExtra {
      keybinds.appHotkeys.append(
        AppHotkey(bundleIdentifier: row.bundleIdentifier, name: row.name, shortcut: shortcut)
      )
    }
    settings.keybinds = keybinds
  }

  private func removeExtra(_ bundleIdentifier: String) {
    settings.keybinds.appHotkeys.removeAll {
      $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame
    }
  }

  private func reloadCatalog() {
    let index = ApplicationIndex()
    index.refresh()
    installed = index.applications.compactMap { app in
      guard app.id.hasPrefix("app:") else {
        return nil
      }
      let identifier = String(app.id.dropFirst(4))
      guard !identifier.isEmpty else {
        return nil
      }
      return AppHotkeyNamedApp(bundleIdentifier: identifier, name: app.name)
    }
    reloadRunning()
  }

  private func reloadRunning() {
    runningApps.refresh()
    runningNamed = NSWorkspace.shared.runningApplications.compactMap { application in
      guard application.activationPolicy == .regular,
            let identifier = application.bundleIdentifier,
            !identifier.isEmpty
      else {
        return nil
      }
      let name = application.localizedName ?? identifier
      return AppHotkeyNamedApp(bundleIdentifier: identifier, name: name)
    }
  }

  private func addApplication() {
    let panel = NSOpenPanel()
    panel.allowedContentTypes = [.application]
    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.prompt = "Add"
    panel.message = "Choose an application that is missing from the list."
    guard panel.runModal() == .OK, let url = panel.url else {
      return
    }
    guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else {
      addError = "\(url.lastPathComponent) has no bundle identifier."
      return
    }
    addError = nil
    let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
      ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
      ?? url.deletingPathExtension().lastPathComponent
    if !installed.contains(where: { $0.bundleIdentifier.caseInsensitiveCompare(identifier) == .orderedSame }) {
      installed.append(AppHotkeyNamedApp(bundleIdentifier: identifier, name: name))
    }
    if !settings.keybinds.appHotkeys.contains(where: {
      $0.bundleIdentifier.caseInsensitiveCompare(identifier) == .orderedSame
    }) {
      settings.keybinds.appHotkeys.append(AppHotkey(bundleIdentifier: identifier, name: name))
    }
  }
}

private struct AppHotkeyCatalogRowView: View {
  let row: AppHotkeyCatalogRow
  @Binding var shortcut: KeyShortcut?
  let conflict: Bool
  let failure: String?
  let onRemoveExtra: (() -> Void)?

  var body: some View {
    HStack(spacing: 10) {
      ZStack(alignment: .bottom) {
        Image(nsImage: icon)
          .resizable()
          .frame(width: 20, height: 20)
        if row.isRunning {
          Circle()
            .fill(Color.primary.opacity(0.78))
            .frame(width: 4, height: 4)
            .offset(y: 3)
        }
      }
      .frame(width: 20, height: 20)
      VStack(alignment: .leading, spacing: 2) {
        Text(row.name)
          .font(.system(size: 14, weight: .medium))
        if let failure {
          Text(failure)
            .font(.system(size: 12))
            .foregroundStyle(.red)
        }
      }
      Spacer(minLength: 8)
      if conflict {
        Text("Also used elsewhere")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      ShortcutField(shortcut: $shortcut)
      if let onRemoveExtra {
        Button(action: onRemoveExtra) {
          Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .help("Remove")
      }
    }
    .padding(.horizontal, 10)
    .frame(minHeight: LauncherLayout.rowHeight)
  }

  private var icon: NSImage {
    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: row.bundleIdentifier) {
      return NSWorkspace.shared.icon(forFile: url.path)
    }
    return NSWorkspace.shared.icon(for: .application)
  }
}

/// Window commands with editable shortcuts.
struct WindowCommandsSection: View {
  @EnvironmentObject private var settings: SettingsStore
  @EnvironmentObject private var keybinds: KeybindsController

  var body: some View {
    PhotonSettingsCard(
      title: "Window management",
      footer: "Every command is also searchable in the launcher, for example \"Left Half\" or \"Maximize\"."
    ) {
      ForEach($settings.keybinds.windowBindings) { $binding in
        HStack(spacing: 10) {
          Text(binding.action.title)
            .font(.system(size: 14, weight: .medium))
          Spacer()
          if conflicts.contains(.window(binding.action)) {
            Text("Also used elsewhere")
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
          }
          if let shortcut = binding.shortcut, let failure = keybinds.registrationFailures[shortcut] {
            Image(systemName: "exclamationmark.circle.fill")
              .foregroundStyle(.red)
              .help(failure)
          }
          ShortcutField(shortcut: $binding.shortcut)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: LauncherLayout.rowHeight)
      }
      Button("Reset to Defaults") {
        settings.keybinds.resetWindowBindings()
      }
      .buttonStyle(.borderless)
      .padding(.horizontal, 10)
      .padding(.bottom, 6)
    }
  }

  private var conflicts: Set<BindingOwner> {
    settings.keybinds.conflictingOwners(launcher: KeyShortcut(settings.hotkey))
  }
}

/// Recorder plus a clear button, bound to an optional `KeyShortcut`.
struct ShortcutField: View {
  @Binding var shortcut: KeyShortcut?
  @EnvironmentObject private var keybinds: KeybindsController

  var body: some View {
    HStack(spacing: 4) {
      OptionalHotkeyRecorder(
        combo: comboBinding,
        title: { KeyShortcut($0).displayString },
        onRecordingChanged: { keybinds.isRecording = $0 }
      )
      .frame(width: 150, height: 24)
      Button {
        shortcut = nil
      } label: {
        Image(systemName: "xmark.circle.fill")
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.borderless)
      .help("Clear shortcut")
      .disabled(shortcut == nil)
      .opacity(shortcut == nil ? 0 : 1)
    }
  }

  private var comboBinding: Binding<HotkeyCombo?> {
    Binding(
      get: { shortcut?.hotkeyCombo },
      set: { combo in
        shortcut = combo.map { KeyShortcut($0) }
      }
    )
  }
}

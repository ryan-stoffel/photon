import AppKit
import PhotonCore
import SwiftUI

struct SettingsRootView: View {
  @ObservedObject var settings: SettingsStore
  @EnvironmentObject private var settingsFocus: SettingsFocusModel
  @FocusState private var focus: SettingsFocusTarget?
  @State private var hostWindow: NSWindow?

  var body: some View {
    HStack(spacing: 0) {
      sidebar
        .frame(width: PhotonSettingsChrome.sidebarWidth)
      Rectangle()
        .fill(Color.primary.opacity(0.08))
        .frame(width: LauncherLayout.hairline)
      SettingsDetailView()
        .id(settings.selectedPane)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.clear)
    .overlay(
      RoundedRectangle(cornerRadius: LauncherLayout.cornerRadius, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.1), lineWidth: LauncherLayout.hairline)
        .allowsHitTesting(false)
    )
    .environment(\.settingsFocus, .some($focus))
    .background(SettingsWindowReader { window in
      if hostWindow !== window {
        hostWindow = window
      }
    })
    .onAppear {
      if let pending = settings.pendingSettingsPane {
        settings.selectedPane = pending
        settings.pendingSettingsPane = nil
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .photonSettingsMoveFocus)) { note in
      guard hostWindow is PhotonSettingsWindow else {
        return
      }
      if (note.userInfo?["reset"] as? Bool) == true {
        focus = nil
        settingsFocus.target = nil
        return
      }
      if let raw = note.userInfo?["target"] as? String, let next = SettingsFocusTarget.parsed(raw) {
        focus = next
        settingsFocus.target = next
        return
      }
      let forward = (note.userInfo?["forward"] as? Bool) ?? true
      moveFocus(forward: forward)
    }
    .onChange(of: focus) { _, newValue in
      guard hostWindow is PhotonSettingsWindow, let newValue else {
        return
      }
      settingsFocus.target = newValue
    }
  }

  private func moveFocus(forward: Bool) {
    let order = SettingsFocusTarget.order(pane: settings.selectedPane)
    guard let first = order.first, let last = order.last else {
      return
    }
    let current = focus ?? settingsFocus.target
    let next: SettingsFocusTarget
    if let current, let index = order.firstIndex(of: current) {
      let destination = index + (forward ? 1 : -1)
      if order.indices.contains(destination) {
        next = order[destination]
      } else {
        next = forward ? first : last
      }
    } else {
      next = forward ? first : last
    }
    focus = next
    settingsFocus.target = next
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 10) {
        Image(nsImage: NSApp.applicationIconImage)
          .resizable()
          .interpolation(.high)
          .frame(width: 28, height: 28)
        Text("Photon")
          .font(.system(size: 14, weight: .medium))
      }
      .padding(.horizontal, 14)
      .padding(.top, PhotonSettingsChrome.trafficLightClearance)
      .frame(
        height: LauncherLayout.searchFieldHeight + PhotonSettingsChrome.trafficLightClearance,
        alignment: .bottomLeading
      )
      .padding(.bottom, 8)

      PhotonSettingsHairline(emphasized: true)

      VStack(spacing: 2) {
        ForEach(SettingsPaneID.allCases) { pane in
          sidebarItem(pane)
        }
      }
      .padding(.horizontal, 8)
      .padding(.top, LauncherLayout.listInset)
      Spacer(minLength: 0)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private func sidebarItem(_ pane: SettingsPaneID) -> some View {
    let selected = settings.selectedPane == pane
    return Button {
      settings.selectedPane = pane
    } label: {
      HStack(spacing: 10) {
        Image(systemName: pane.symbolName)
          .font(.system(size: 13, weight: .semibold))
          .frame(width: 18)
        Text(pane.title)
          .font(.system(size: 14, weight: .medium))
        Spacer(minLength: 0)
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 10)
      .frame(height: LauncherLayout.rowHeight)
      .background(
        RoundedRectangle(cornerRadius: PhotonSettingsChrome.rowCornerRadius, style: .continuous)
          .fill(selected ? Color.primary.opacity(0.09) : Color.clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .focused($focus, equals: .sidebar(pane))
    .focusEffectDisabled()
    .overlay(
      RoundedRectangle(cornerRadius: PhotonSettingsChrome.rowCornerRadius, style: .continuous)
        .strokeBorder(Color.accentColor.opacity(focus == .sidebar(pane) ? 1 : 0), lineWidth: 2)
        .padding(1)
        .allowsHitTesting(false)
    )
  }
}

private struct SettingsWindowReader: NSViewRepresentable {
  var onWindow: (NSWindow?) -> Void

  func makeNSView(context _: Context) -> NSView {
    let view = NSView(frame: .zero)
    DispatchQueue.main.async {
      onWindow(view.window)
    }
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    DispatchQueue.main.async {
      onWindow(nsView.window)
    }
  }
}

struct SettingsDetailView: View {
  @EnvironmentObject private var settings: SettingsStore

  var body: some View {
    switch settings.selectedPane {
    case .general:
      GeneralSettingsView()
    case .appearance:
      AppearanceSettingsView()
    case .clipboard:
      ClipboardSettingsView()
    case .notes:
      NotesSettingsView()
    case .files:
      FilesSettingsView()
    case .keybinds:
      KeybindsSettingsView()
    case .about:
      AboutSettingsView()
    }
  }
}

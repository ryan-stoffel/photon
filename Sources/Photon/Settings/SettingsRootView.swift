import AppKit
import PhotonCore
import SwiftUI

struct SettingsRootView: View {
  @EnvironmentObject private var settings: SettingsStore

  var body: some View {
    GeometryReader { geo in
      HStack(spacing: 0) {
        sidebar
          .frame(width: PhotonSettingsChrome.sidebarWidth)
        PhotonSettingsHairline()
          .frame(maxHeight: .infinity)
        SettingsDetailView(pane: settings.selectedPane)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      }
      .frame(width: geo.size.width, height: geo.size.height)
      .background(Color.clear)
      .overlay(
        RoundedRectangle(cornerRadius: LauncherLayout.cornerRadius, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.1), lineWidth: LauncherLayout.hairline)
          .allowsHitTesting(false)
      )
    }
    .onAppear {
      if let pending = settings.pendingSettingsPane {
        settings.selectedPane = pending
        settings.pendingSettingsPane = nil
      }
    }
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
  }
}

struct SettingsDetailView: View {
  let pane: SettingsPaneID

  var body: some View {
    switch pane {
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

import SwiftUI

struct SettingsRootView: View {
  @EnvironmentObject private var settings: SettingsStore

  var body: some View {
    NavigationSplitView {
      List(selection: $settings.selectedPane) {
        ForEach(SettingsPaneID.allCases) { pane in
          Label(pane.title, systemImage: pane.symbolName)
            .tag(pane)
        }
      }
      .listStyle(.sidebar)
      .navigationSplitViewColumnWidth(min: 180, ideal: 208, max: 240)
      .navigationTitle("Photon")
    } detail: {
      SettingsDetailView(pane: settings.selectedPane)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(settings.selectedPane.title)
    }
    .navigationSplitViewStyle(.balanced)
    .tint(.accentColor)
    .font(.system(.body))
    .onAppear {
      if let pending = settings.pendingSettingsPane {
        settings.selectedPane = pending
        settings.pendingSettingsPane = nil
      }
    }
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

struct PlaceholderSettingsView<Content: View>: View {
  let title: String
  let detail: String
  @ViewBuilder var content: () -> Content

  var body: some View {
    Form {
      Section {
        Text(detail)
          .foregroundStyle(.secondary)
      }
      content()
    }
    .formStyle(.grouped)
    .navigationTitle(title)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

import SwiftUI

struct GeneralSettingsView: View {
  @EnvironmentObject private var settings: SettingsStore

  var body: some View {
    PhotonSettingsPage(title: "General") {
      PhotonSettingsCard(
        title: "Hotkey",
        footer: "Photon registers this shortcut globally. If Spotlight still owns it, disable "
          + "Spotlight’s shortcut under System Settings > Keyboard > Keyboard Shortcuts > Spotlight."
      ) {
        PhotonSettingsRow(title: "Open launcher") {
          HotkeyRecorder(combo: $settings.hotkey)
            .frame(width: 180, height: 24)
        }
        Button("Open Keyboard Settings") {
          SpotlightConflict.openKeyboardSettings()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
      }

      PhotonSettingsCard(title: "Startup") {
        PhotonSettingsRow(title: "Launch at login") {
          Toggle("", isOn: $settings.launchAtLogin)
            .toggleStyle(.switch)
            .labelsHidden()
        }
        if let launchAtLoginError = settings.launchAtLoginError {
          Text(launchAtLoginError)
            .font(.system(size: 12))
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
      }
    }
  }
}

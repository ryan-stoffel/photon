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
        if let hotkeyClash {
          Text("\(hotkeyClash) also uses this shortcut. Only one of them can have it.")
            .font(.system(size: 12))
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
        Button("Open Keyboard Settings") {
          SpotlightConflict.openKeyboardSettings()
        }
        .buttonStyle(.borderless)
        .settingsFocused(.control("general.keyboardSettings"))
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
      }

      PhotonSettingsCard(title: "Startup") {
        PhotonSettingsRow(title: "Launch at login") {
          Toggle("", isOn: $settings.launchAtLogin)
            .toggleStyle(.switch)
            .labelsHidden()
            .settingsFocused(.control("general.launchAtLogin"))
        }
        if let launchAtLoginError = settings.launchAtLoginError {
          Text(launchAtLoginError)
            .font(.system(size: 12))
            .foregroundStyle(.red)
            .padding(.horizontal, 10)
            .padding(.bottom, 6)
        }
      }

      PhotonSettingsCard(title: "Introduction") {
        PhotonSettingsRow(
          title: "Welcome",
          detail: "Shows the first-run window again."
        ) {
          Button("Show again") {
            settings.replayOnboarding?()
          }
          .buttonStyle(.borderless)
          .settingsFocused(.control("general.replayOnboarding"))
        }
      }
    }
  }

  /// The other Photon feature registered on the launcher hotkey, if any. Carbon rejects the second registration.
  private var hotkeyClash: String? {
    if settings.clipboardEnabled, settings.clipboardHotkeyEnabled, settings.clipboardHotkey == settings.hotkey {
      return "Clipboard History"
    }
    if settings.notesHotkey == settings.hotkey {
      return "Notes"
    }
    return nil
  }
}

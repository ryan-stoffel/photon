import PhotonCore
import SwiftUI

struct AppearanceSettingsView: View {
  @EnvironmentObject private var settings: SettingsStore

  var body: some View {
    PhotonSettingsPage(title: "Appearance") {
      PhotonSettingsCard(
        title: "Launcher",
        footer: "Click and drag anywhere on the launcher to move it; a small slop keeps row and button "
          + "clicks working. Dotted guides mark the left and right edges of a centered panel. "
          + "Releasing while the panel center is between those guides snaps back to screen center."
      ) {
        PhotonSettingsRow(
          title: "Show suggestions before typing",
          detail: "On: the launcher opens with your most used apps and commands. "
            + "Off: it stays a single search field until you type."
        ) {
          Toggle("", isOn: $settings.launcherShowsSuggestions)
            .toggleStyle(.switch)
            .labelsHidden()
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("Panel width")
            .font(.system(size: 14, weight: .medium))
          Picker("Panel width", selection: $settings.launcherPanelWidth) {
            ForEach(LauncherPanelWidth.allCases) { width in
              Text(width.title).tag(width)
            }
          }
          .pickerStyle(.segmented)
          .labelsHidden()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        Button("Reset launcher position to center") {
          settings.resetLauncherPositionToCenter()
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
      }

      PhotonSettingsCard(
        title: "Appearance",
        footer: "Applies to the launcher, notes, and this window."
      ) {
        Picker("Appearance", selection: $settings.appearance) {
          ForEach(AppAppearance.allCases) { appearance in
            Text(appearance.title).tag(appearance)
          }
        }
        .pickerStyle(.segmented)
        .padding(10)
      }
    }
  }
}

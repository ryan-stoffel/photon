import AppKit
import PhotonNotes
import SwiftUI

struct NotesSettingsView: View {
  @EnvironmentObject private var settings: SettingsStore

  private let directory = NoteStore.defaultDirectory()

  var body: some View {
    PhotonSettingsPage(title: "Notes") {
      PhotonSettingsCard(
        title: "Editor",
        footer: "⌘+ and ⌘- change the size from the notes window as well."
      ) {
        PhotonSettingsRow(title: "Text size") {
          Stepper(
            value: $settings.notesFontSize,
            in: NotesPreferences.fontSizeRange,
            step: NotesPreferences.fontSizeStep
          ) {
            Text("\(Int(settings.notesFontSize)) pt")
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
          .settingsFocused(.control("notes.size"))
        }
      }

      PhotonSettingsCard(title: "Window") {
        PhotonSettingsRow(title: "Float above other windows") {
          Toggle("", isOn: $settings.notesFloatsAboveOtherWindows)
            .toggleStyle(.switch)
            .labelsHidden()
            .settingsFocused(.control("notes.float"))
        }
        PhotonSettingsRow(title: "Open notes when Photon launches") {
          Toggle("", isOn: $settings.notesOpenOnLaunch)
            .toggleStyle(.switch)
            .labelsHidden()
            .settingsFocused(.control("notes.launch"))
        }
      }

      PhotonSettingsCard(
        title: "Shortcut",
        footer: "Notes are always available from the launcher: type “notes”, or “n” followed by a title."
      ) {
        PhotonSettingsRow(title: "Toggle notes window") {
          HStack(spacing: 8) {
            OptionalHotkeyRecorder(combo: $settings.notesHotkey)
              .frame(width: 180, height: 24)
            if settings.notesHotkey != nil {
              Button("Remove") {
                settings.notesHotkey = nil
              }
              .buttonStyle(.borderless)
            }
          }
        }
      }

      PhotonSettingsCard(title: "Storage", footer: "One markdown file per note. The first line is the title.") {
        PhotonSettingsRow(title: "Location") {
          Text(abbreviatedPath)
            .font(.callout.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
            .multilineTextAlignment(.trailing)
        }
        HStack {
          Spacer()
          Button("Show in Finder") {
            showInFinder()
          }
          .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
      }
    }
  }

  private var abbreviatedPath: String {
    (directory.path as NSString).abbreviatingWithTildeInPath
  }

  private func showInFinder() {
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    NSWorkspace.shared.open(directory)
  }
}

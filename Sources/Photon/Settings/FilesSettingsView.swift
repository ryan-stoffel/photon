import AppKit
import PhotonCore
import PhotonFiles
import SwiftUI

struct FilesSettingsView: View {
  @EnvironmentObject private var settings: SettingsStore
  @EnvironmentObject private var fileAccess: FileAccessCoordinator

  var body: some View {
    PhotonSettingsPage(title: "Files") {
      PhotonSettingsCard(
        title: "Search",
        footer: "Matches words inside documents as well as names. Slower on large libraries."
      ) {
        PhotonSettingsRow(title: "Look in") {
          Picker("Look in", selection: $settings.filesSearchScope) {
            ForEach(FileSearchScope.allCases, id: \.rawValue) { scope in
              Text(scope.title).tag(scope.rawValue)
            }
          }
          .labelsHidden()
          .settingsFocused(.control("files.scope"))
          .frame(maxWidth: 220)
        }
        PhotonSettingsRow(title: "Search file contents") {
          Toggle("", isOn: $settings.filesSearchContents)
            .toggleStyle(.switch)
            .labelsHidden()
            .settingsFocused(.control("files.contents"))
        }
        PhotonSettingsRow(title: "Show up to \(settings.filesMaxResults) results") {
          Stepper(
            value: $settings.filesMaxResults,
            in: FileSearchSettings.maxResultsRange,
            step: 10
          ) {
            EmptyView()
          }
          .settingsFocused(.control("files.maxResults"))
        }
      }

      PhotonSettingsCard(
        title: "Actions",
        footer: "Command-Enter performs the other action. Space or Command-Y opens Quick Look. "
          + "Up to three strong matches appear below applications once you have typed three characters."
      ) {
        PhotonSettingsRow(title: "Enter") {
          Picker("Enter", selection: $settings.filesDefaultAction) {
            ForEach(FileDefaultAction.allCases, id: \.rawValue) { action in
              Text(action.title).tag(action.rawValue)
            }
          }
          .labelsHidden()
          .frame(maxWidth: 180)
        }
        PhotonSettingsRow(title: "Show file matches in the main list") {
          Toggle("", isOn: $settings.filesInlineResults)
            .toggleStyle(.switch)
            .labelsHidden()
        }
      }

      PhotonSettingsCard(
        title: "Folder Access",
        footer: "Photon stores security-scoped bookmarks so access survives relaunch."
      ) {
        if fileAccess.grants.isEmpty {
          PhotonSettingsCaption(
            text: "Choose only the folders Photon may search directly when Spotlight has no match."
          )
        }
        ForEach(fileAccess.grants) { grant in
          HStack(spacing: 8) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: grant.path))
              .resizable()
              .frame(width: 16, height: 16)
            Text(PathFormatter.abbreviatingHome(grant.path))
              .lineLimit(1)
              .truncationMode(.middle)
            Spacer()
            Button("Remove", systemImage: "minus.circle") {
              fileAccess.remove(path: grant.path)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
          }
          .padding(.horizontal, 10)
          .frame(height: LauncherLayout.rowHeight)
        }
        Button(fileAccess.grants.isEmpty ? "Choose Folders…" : "Add Folder…") {
          fileAccess.requestAccess(parent: NSApp.keyWindow)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        if fileAccess.status == .requesting {
          ProgressView()
            .controlSize(.small)
            .padding(.horizontal, 10)
        } else if let message = fileAccess.statusMessage {
          Text(message)
            .font(.system(size: 12))
            .foregroundStyle(.orange)
            .padding(.horizontal, 10)
        }
      }

      PhotonSettingsCard(
        title: "Never search",
        footer: "Folders listed under System Settings > Siri & Spotlight > Spotlight Privacy "
          + "are already excluded by Spotlight."
      ) {
        FolderListEditor(
          folders: $settings.filesExcludedFolders,
          emptyText: "Files inside these folders never appear in results."
        )
      }
    }
  }
}

private struct FolderListEditor: View {
  @Binding var folders: [String]
  let emptyText: String

  var body: some View {
    if folders.isEmpty {
      PhotonSettingsCaption(text: emptyText)
    }
    ForEach(folders, id: \.self) { folder in
      HStack(spacing: 8) {
        Image(nsImage: NSWorkspace.shared.icon(forFile: folder))
          .resizable()
          .frame(width: 16, height: 16)
        Text(PathFormatter.abbreviatingHome(folder))
          .lineLimit(1)
          .truncationMode(.middle)
          .help(folder)
        Spacer()
        Button("Remove", systemImage: "minus.circle") {
          folders.removeAll { $0 == folder }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
      }
      .padding(.horizontal, 10)
      .frame(height: LauncherLayout.rowHeight)
    }
    Button("Add Folder\u{2026}") {
      addFolders()
    }
    .buttonStyle(.borderless)
    .padding(.horizontal, 10)
    .padding(.bottom, 6)
  }

  private func addFolders() {
    let panel = NSOpenPanel()
    panel.canChooseDirectories = true
    panel.canChooseFiles = false
    panel.allowsMultipleSelection = true
    panel.prompt = "Add"
    panel.message = "Choose folders"
    guard panel.runModal() == .OK else {
      return
    }
    for url in panel.urls {
      let path = url.standardizedFileURL.path(percentEncoded: false)
      let trimmed = path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
      if !folders.contains(trimmed) {
        folders.append(trimmed)
      }
    }
  }
}

import Foundation
import PhotonApps
import PhotonKeybinds
import PhotonNotes

extension NativeParityReporter {
  func dispatchParityCommand(_ command: String, runtime: AppRuntime) {
    if handleNotesParityCommand(command, notes: runtime.notes.controller) {
      return
    }
    handleLauncherParityCommand(command, runtime: runtime)
  }

  private func handleNotesParityCommand(_ command: String, notes: NotesController) -> Bool {
    switch command {
    case "showNotes":
      notes.show(focus: true)
    case "seedNotes":
      _ = notes.createNote(content: "# JIRA API KEY\nsecret")
      _ = notes.createNote(content: "Test\n\nbla bla")
    case "seedAndShowNotes":
      _ = notes.createNote(content: "# JIRA API KEY\nsecret")
      _ = notes.createNote(content: "Test\n\nbla bla")
      notes.show(focus: true)
    case "showNotesSwitcher":
      notes.presentSwitcher()
    case "showNotesActions":
      notes.presentActions()
    case "showNotesFormat":
      notes.presentFormatBar()
    case "hideNotes":
      notes.hide()
    default:
      return false
    }
    return true
  }

  private func handleLauncherParityCommand(_ command: String, runtime: AppRuntime) {
    if command == "hideLauncher" {
      runtime.launcher.hide()
    } else if command == "showLauncher" {
      runtime.launcher.show()
    } else if command == "resetLauncherPosition" {
      runtime.settings.resetLauncherPositionToCenter()
      if let panel = runtime.launcher.panel {
        runtime.launcher.position(panel)
      }
    } else if command == "openSettings" {
      runtime.openSettings()
    } else if command == "hideSettings" {
      runtime.closeSettings()
    } else if command == "refreshAppearance" {
      runtime.applyAppearance()
    } else if command == "restoreAgent" {
      runtime.restoreAccessoryPolicy()
    } else if command == "suppressAutoHide" {
      runtime.launcher.suppressAutoHide(for: 60)
    } else {
      handleLauncherPrefixCommand(command, runtime: runtime)
    }
  }

  private func handleLauncherPrefixCommand(_ command: String, runtime: AppRuntime) {
    if command.hasPrefix("showFiles:") {
      runtime.launcher.showFilesMode(query: String(command.dropFirst("showFiles:".count)))
    } else if command.hasPrefix("setFilesQuery:") {
      runtime.launcher.model.query = String(command.dropFirst("setFilesQuery:".count))
    } else if command.hasPrefix("requestFileAccess:") {
      let query = String(command.dropFirst("requestFileAccess:".count))
      runtime.fileSearch?.controller.update(query: query)
      runtime.fileSearch?.controller.requestFileAccess()
    } else if command.hasPrefix("selectLauncherIndex:") {
      let raw = String(command.dropFirst("selectLauncherIndex:".count))
      guard let index = Int(raw) else {
        return
      }
      let results = runtime.launcher.model.results
      guard results.indices.contains(index) else {
        return
      }
      runtime.launcher.model.selectedID = results[index].id
    } else if command.hasPrefix("launchForeground:") {
      let identifier = String(command.dropFirst("launchForeground:".count))
      runtime.launcher.hide(restorePrevious: false)
      Task { @MainActor in
        _ = try? await ForegroundActivation.launch(bundleIdentifier: identifier)
        runtime.restoreAccessoryPolicy()
      }
    } else if command.hasPrefix("hideForeground:") {
      let identifier = String(command.dropFirst("hideForeground:".count))
      ForegroundActivation.runningApplication(bundleIdentifier: identifier)?.hide()
      runtime.restoreAccessoryPolicy()
    } else if command.hasPrefix("moveLauncherSelection:") {
      let raw = String(command.dropFirst("moveLauncherSelection:".count))
      runtime.launcher.model.moveSelection(Int(raw) ?? 0)
    } else if command == "refreshRunningApps" {
      runtime.runningApps.refresh()
    } else if command.hasPrefix("setLauncherQuery:") {
      runtime.launcher.model.query = String(command.dropFirst("setLauncherQuery:".count))
    } else if command.hasPrefix("selectLauncherApp:") {
      selectLauncherApp(String(command.dropFirst("selectLauncherApp:".count)), runtime: runtime)
    } else if command.hasPrefix("seedAppHotkey:") {
      seedAppHotkey(String(command.dropFirst("seedAppHotkey:".count)), runtime: runtime)
    }
  }

  private func selectLauncherApp(_ identifier: String, runtime: AppRuntime) {
    let commandID = "app:\(identifier)"
    if let ranked = runtime.launcher.model.results.first(where: {
      $0.id.caseInsensitiveCompare(commandID) == .orderedSame
    }) {
      runtime.launcher.model.selectedID = ranked.id
    }
  }

  private func seedAppHotkey(_ payload: String, runtime: AppRuntime) {
    let parts = payload.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
    guard parts.count == 2, let shortcut = KeyShortcut.parse(String(parts[1])) else {
      return
    }
    let identifier = String(parts[0])
    var keybinds = runtime.settings.keybinds
    if let index = keybinds.appHotkeys.firstIndex(where: {
      $0.bundleIdentifier.caseInsensitiveCompare(identifier) == .orderedSame
    }) {
      keybinds.appHotkeys[index].shortcut = shortcut
    } else {
      keybinds.appHotkeys.append(
        AppHotkey(bundleIdentifier: identifier, name: identifier, shortcut: shortcut)
      )
    }
    runtime.settings.keybinds = keybinds
  }
}

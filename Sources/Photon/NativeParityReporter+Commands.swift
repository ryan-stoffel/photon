import AppKit
import Foundation
import PhotonApps
import PhotonCore
import PhotonFiles
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
    if handleLauncherWindowCommand(command, runtime: runtime) {
      return
    }
    if handleSettingsParityCommand(command, runtime: runtime) {
      return
    }
    if handleOnboardingParityCommand(command, runtime: runtime) {
      return
    }
    if command == "resetLauncherPosition" {
      runtime.settings.resetLauncherPositionToCenter()
      if let panel = runtime.launcher.panel {
        runtime.launcher.position(panel)
      }
    } else if command == "restoreAgent" {
      runtime.restoreAccessoryPolicy()
    } else if command == "suppressAutoHide" {
      runtime.launcher.suppressAutoHide(for: 60)
    } else if command == "holdCommandList" {
      Self.suppressFilesPromotion = true
      runtime.launcher.model.exitMode(clearingQuery: false)
    } else if command == "releaseCommandList" {
      Self.suppressFilesPromotion = false
    } else {
      handleLauncherPrefixCommand(command, runtime: runtime)
    }
  }

  private func handleSettingsParityCommand(_ command: String, runtime: AppRuntime) -> Bool {
    switch command {
    case "openSettings":
      runtime.openSettings()
    case "hideSettings":
      runtime.closeSettings()
    case "moveSettingsFocus":
      SettingsFocusRouting.move(forward: true)
    case "resetSettingsFocus":
      SettingsFocusRouting.reset()
    case "refreshAppearance":
      runtime.applyAppearance()
    default:
      return handleSettingsPrefixCommand(command, runtime: runtime)
    }
    return true
  }

  private func handleSettingsPrefixCommand(_ command: String, runtime: AppRuntime) -> Bool {
    if command.hasPrefix("selectSettingsPane:") {
      let raw = String(command.dropFirst("selectSettingsPane:".count))
      if let pane = SettingsPaneID(rawValue: raw) {
        runtime.settings.selectedPane = pane
        runtime.openSettings()
      }
      return true
    }
    if command.hasPrefix("focusSettings:") {
      SettingsFocusRouting.focus(report: String(command.dropFirst("focusSettings:".count)))
      return true
    }
    return false
  }

  private func handleOnboardingParityCommand(_ command: String, runtime: AppRuntime) -> Bool {
    switch command {
    case "showOnboarding":
      let onboarding = runtime.makeOnboarding()
      onboarding.present(hotkey: runtime.settings.hotkey)
    case "advanceOnboarding":
      runtime.onboarding?.advance()
    case "dismissOnboarding":
      runtime.onboarding?.finish()
    default:
      return false
    }
    return true
  }

  private func handleLauncherWindowCommand(_ command: String, runtime: AppRuntime) -> Bool {
    switch command {
    case "hideLauncher":
      runtime.launcher.hide()
    case "showLauncher":
      runtime.launcher.show()
    case "dismissLauncher":
      runtime.launcher.hide(restorePrevious: false)
    default:
      return false
    }
    return true
  }

  private func handleLauncherPrefixCommand(_ command: String, runtime: AppRuntime) {
    if handleFileParityCommand(command, runtime: runtime) {
      return
    }
    if handleLaunchParityCommand(command, runtime: runtime) {
      return
    }
    handleRowChromeParityCommand(command, runtime: runtime)
  }

  private func handleFileParityCommand(_ command: String, runtime: AppRuntime) -> Bool {
    if command.hasPrefix("showFiles:") {
      runtime.launcher.showFilesMode(query: String(command.dropFirst("showFiles:".count)))
      return true
    }
    if command.hasPrefix("setFilesQuery:") {
      runtime.launcher.model.query = String(command.dropFirst("setFilesQuery:".count))
      return true
    }
    if command.hasPrefix("requestFileAccess:") {
      let query = String(command.dropFirst("requestFileAccess:".count))
      runtime.fileSearch?.controller.update(query: query)
      runtime.fileSearch?.controller.requestFileAccess()
      return true
    }
    return false
  }

  private func handleLaunchParityCommand(_ command: String, runtime: AppRuntime) -> Bool {
    if command.hasPrefix("selectLauncherIndex:") {
      let raw = String(command.dropFirst("selectLauncherIndex:".count))
      guard let index = Int(raw) else {
        return true
      }
      let results = runtime.launcher.model.results
      guard results.indices.contains(index) else {
        return true
      }
      runtime.launcher.model.selectedID = results[index].id
      return true
    }
    if command.hasPrefix("launchForeground:") {
      let identifier = String(command.dropFirst("launchForeground:".count))
      runtime.launcher.hide(restorePrevious: false)
      Task { @MainActor in
        _ = try? await ForegroundActivation.launch(bundleIdentifier: identifier)
        runtime.restoreAccessoryPolicy()
      }
      return true
    }
    if command.hasPrefix("hideForeground:") {
      let identifier = String(command.dropFirst("hideForeground:".count))
      runtime.launcher.hide(restorePrevious: false)
      ForegroundActivation.runningApplication(bundleIdentifier: identifier)?.hide()
      runtime.restoreAccessoryPolicy()
      return true
    }
    if command.hasPrefix("terminateForeground:") {
      let identifier = String(command.dropFirst("terminateForeground:".count))
      ForegroundActivation.runningApplication(bundleIdentifier: identifier)?.terminate()
      runtime.restoreAccessoryPolicy()
      return true
    }
    if command.hasPrefix("moveLauncherSelection:") {
      let raw = String(command.dropFirst("moveLauncherSelection:".count))
      runtime.launcher.model.moveSelection(Int(raw) ?? 0)
      return true
    }
    return false
  }

  private func handleRowChromeParityCommand(_ command: String, runtime: AppRuntime) {
    if command == "refreshRunningApps" {
      runtime.runningApps.refresh()
    } else if command == "revealRecommendations" {
      runtime.launcher.model.revealRecommendations()
      Task { await runtime.launcher.model.refresh() }
    } else if command.hasPrefix("setLauncherQuery:") {
      runtime.launcher.model.query = String(command.dropFirst("setLauncherQuery:".count))
    } else if command.hasPrefix("selectLauncherApp:") {
      selectLauncherApp(String(command.dropFirst("selectLauncherApp:".count)), runtime: runtime)
    } else if command.hasPrefix("seedAppHotkey:") {
      seedAppHotkey(String(command.dropFirst("seedAppHotkey:".count)), runtime: runtime)
    } else if command.hasPrefix("seedUsage:") {
      seedUsage(String(command.dropFirst("seedUsage:".count)), runtime: runtime)
    }
  }

  private func seedUsage(_ payload: String, runtime: AppRuntime) {
    let parts = payload.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
    guard let rawID = parts.first else {
      return
    }
    let count = parts.count > 1 ? Int(parts[1]) ?? 1 : 1
    let identifier = String(rawID)
    let commandID = identifier.hasPrefix("app:") ? identifier : "app:\(identifier)"
    runtime.launcher.model.frecency.setUseCount(id: commandID, count: count)
    Task { await runtime.launcher.model.refresh() }
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

  func selectedIsRunning(_ model: LauncherViewModel) -> Bool {
    guard let row = model.selectedRow else {
      return false
    }
    return row.showsRunningIndicator(runningBundleIDs: runtime?.runningApps.bundleIdentifiers ?? [])
  }

  func selectedShortcutChips(_ model: LauncherViewModel) -> [String] {
    guard let row = model.selectedRow, let runtime else {
      return []
    }
    return LauncherRowChrome.shortcutChips(
      commandID: row.id,
      keybinds: runtime.settings.keybinds,
      clipboardHotkeyEnabled: runtime.settings.clipboardHotkeyEnabled,
      clipboardHotkey: runtime.settings.clipboardHotkey,
      notesHotkey: runtime.settings.notesHotkey
    )
  }

  func runningAppRowTitles(_ model: LauncherViewModel) -> [String] {
    let running = runtime?.runningApps.bundleIdentifiers ?? []
    return model.rows.compactMap { row in
      row.showsRunningIndicator(runningBundleIDs: running) ? row.title : nil
    }
  }

  func onboardingReport(_ runtime: AppRuntime) -> [String: Any] {
    guard let onboarding = runtime.onboarding else {
      return [
        "visible": false,
        "windowNumber": 0,
        "step": "",
        "title": "",
      ]
    }
    return [
      "visible": onboarding.isVisible,
      "windowNumber": onboarding.windowNumber,
      "step": onboarding.step.title,
      "title": onboarding.step.title,
    ]
  }

  func runningAppsLeadList(_ model: LauncherViewModel) -> Bool {
    guard !model.rows.isEmpty else {
      return false
    }
    let running = runtime?.runningApps.bundleIdentifiers ?? []
    var seenRest = false
    for row in model.rows {
      if row.showsRunningIndicator(runningBundleIDs: running) {
        if seenRest {
          return false
        }
      } else {
        seenRest = true
      }
    }
    return true
  }

  func settingsWindowReport(_ runtime: AppRuntime) -> [String: Any] {
    guard let window = runtime.existingSettingsWindow() else {
      return [
        "exists": false,
        "visible": false,
        "key": false,
        "title": "",
        "windowNumber": 0,
      ]
    }
    return [
      "exists": true,
      "visible": window.isVisible,
      "key": window.isKeyWindow,
      "title": window.title,
      "windowNumber": window.windowNumber,
      "class": window.className,
      "photonChrome": window is PhotonSettingsWindow
        || window.contentView?.identifier?.rawValue == PhotonSettingsChrome.contentIdentifier.rawValue,
      "cornerRadius": LauncherLayout.cornerRadius,
    ]
  }

  func hostReport() -> [String: Any] {
    let version = ProcessInfo.processInfo.operatingSystemVersion
    return [
      "os": ProcessInfo.processInfo.operatingSystemVersionString,
      "major": version.majorVersion,
      "minor": version.minorVersion,
      "patch": version.patchVersion,
      "glassAvailable": PhotonPanelChrome.glassEffectAvailable,
    ]
  }

  func notesReport(_ controller: NotesController) -> [String: Any] {
    [
      "visible": controller.isWindowVisible,
      "width": controller.windowWidth,
      "height": controller.windowHeight,
      "windowNumber": controller.windowNumber,
      "overlay": controller.overlayName,
      "title": controller.screenshotWindow?.title ?? "",
      "characterCount": controller.currentNote?.characterCount ?? 0,
    ]
  }

  func contentName(_ content: LauncherContent) -> String {
    switch content {
    case .searchOnly:
      "searchOnly"
    case .recommendations:
      "recommendations"
    case .rows:
      "rows"
    case .fullHeight:
      "fullHeight"
    }
  }

  func fileStatus(_ status: FileSearchController.Status?) -> String {
    switch status {
    case .idle:
      "idle"
    case .searching:
      "searching"
    case .recents:
      "recents"
    case .noRecents:
      "noRecents"
    case .results:
      "results"
    case .empty:
      "empty"
    case .unavailable:
      "unavailable"
    case .needsAccess:
      "needsAccess"
    case nil:
      ""
    }
  }

  func fileAccessStatus(_ status: FileAccessCoordinator.Status) -> String {
    switch status {
    case .idle:
      "idle"
    case .requesting:
      "requesting"
    case .granted:
      "granted"
    case .cancelled:
      "cancelled"
    case .failed:
      "failed"
    }
  }

  func launcherPositionReport(_ position: LauncherStoredPosition?) -> [String: Any] {
    guard let position else {
      return ["exists": false]
    }
    return [
      "exists": true,
      "x": position.originX,
      "y": position.originY,
      "centered": position.isHorizontallyCentered,
    ]
  }

  func colorComponents(_ color: NSColor, appearance: NSAppearance) -> [String: Double] {
    var resolved: NSColor?
    appearance.performAsCurrentDrawingAppearance {
      resolved = color.usingColorSpace(.deviceRGB)
    }
    guard let resolved else {
      return [:]
    }
    return [
      "red": resolved.redComponent,
      "green": resolved.greenComponent,
      "blue": resolved.blueComponent,
      "alpha": resolved.alphaComponent,
    ]
  }
}

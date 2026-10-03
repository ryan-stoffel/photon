import AppKit
import PhotonApps
import PhotonCore
import PhotonFiles

extension LauncherViewModel {
  /// Actions for the selected root row, primary (↵) first.
  func rootActions() -> [LauncherAction] {
    guard let command = results.first(where: { $0.id == selectedID })?.command else {
      return []
    }
    let primary: @MainActor () async -> Bool = { [weak self] in
      await self?.runSelection() ?? false
    }
    if command.providerID == "calculator" {
      return [LauncherAction(id: "calculator.copyAnswer", title: "Copy Answer", symbol: "doc.on.doc", run: primary)]
    }
    if let path = FilesProvider.path(forCommandID: command.id) {
      return [
        LauncherAction(id: "file.open", title: "Open", symbol: "arrow.up.forward.app", run: primary),
        showInFinder(id: "file.showInFinder", url: URL(fileURLWithPath: path)),
        copy(id: "file.copyPath", title: "Copy Path", value: path, modifier: .option),
      ]
    }
    let title = if command.id.hasPrefix("app:") {
      "Open Application"
    } else if command.id.hasPrefix("pane:") || command.id.hasPrefix("note:") {
      "Open"
    } else {
      "Open Command"
    }
    var actions = [LauncherAction(id: "command.open", title: title, symbol: "arrow.up.forward.app", run: primary)]
    if showsFallbacks {
      return actions
    }
    if let url = (registry.provider(id: "apps") as? AppsProvider)?.applicationURL(for: command) {
      actions += appActions(command: command, url: url)
    }
    actions.append(LauncherAction(
      id: "command.resetRanking",
      title: "Reset Ranking",
      symbol: "arrow.counterclockwise",
      shortcut: LauncherShortcut(keyCode: 15, modifiers: [.option, .command], key: "R")
    ) { [weak self] in
      self?.frecency.setUseCount(id: command.id, count: 0)
      await self?.refresh()
      return false
    })
    return actions
  }

  /// What ⌘K lists and what shortcut dispatch matches: the active mode's, the clipboard's, or the root row's.
  var currentActions: [LauncherAction] {
    if let activeMode {
      return activeMode.actions()
    }
    if session == .clipboard {
      return clipboardActions()
    }
    return rootActions()
  }

  private func appActions(command: Command, url: URL) -> [LauncherAction] {
    var actions = [
      showInFinder(id: "app.showInFinder", url: url),
      copy(id: "app.copyPath", title: "Copy Path", value: url.path, modifier: .option),
      copy(id: "app.copyName", title: "Copy Name", value: command.title, modifier: .control),
    ]
    guard let bundleID = LauncherRow.applicationBundleIdentifier(commandID: command.id, providerID: command.providerID)
    else {
      return actions
    }
    actions.append(copy(id: "app.copyBundleID", title: "Copy Bundle Identifier", value: bundleID, modifier: .shift))
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    if !running.isEmpty {
      actions.append(LauncherAction(
        id: "app.quit",
        title: "Quit Application",
        symbol: "xmark.circle",
        shortcut: LauncherShortcut(keyCode: 12, modifiers: [.control, .shift], key: "Q")
      ) {
        running.forEach { $0.terminate() }
        return true
      })
    }
    return actions
  }

  /// Reveals `url` in Finder on ⌘↵ and hides the launcher so Finder stays in front.
  private func showInFinder(id: String, url: URL) -> LauncherAction {
    LauncherAction(id: id, title: "Show in Finder", symbol: "finder", shortcut: .commandReturn) {
      NSWorkspace.shared.activateFileViewerSelecting([url])
      return true
    }
  }

  /// Copies `value` and hides. The shortcut is `modifier` plus ⌘C.
  private func copy(id: String, title: String, value: String, modifier: NSEvent.ModifierFlags) -> LauncherAction {
    LauncherAction(
      id: id,
      title: title,
      symbol: "doc.on.doc",
      shortcut: LauncherShortcut(keyCode: 8, modifiers: [modifier, .command], key: "C")
    ) {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(value, forType: .string)
      return true
    }
  }
}

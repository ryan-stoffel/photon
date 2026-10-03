extension LauncherViewModel {
  /// Actions for the selected root row, primary (↵) first.
  func rootActions() -> [LauncherAction] {
    []
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
}

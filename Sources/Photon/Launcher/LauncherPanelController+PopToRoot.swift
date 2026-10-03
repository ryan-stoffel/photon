import Foundation

/// The view `hide(popToRoot: false)` left behind.
struct LauncherPopState {
  let date: Date
  let session: LauncherSession
  let modeID: String?
  let query: String
}

extension LauncherPanelController {
  /// Raycast's "Pop to Root Search" delay.
  static let popToRootDelay: TimeInterval = 90

  /// Reopening within `popToRootDelay` of a dismissal returns to the same view and query.
  func restorePopState() {
    defer {
      popState = nil
    }
    guard let state = popState, Date().timeIntervalSince(state.date) < Self.popToRootDelay else {
      return
    }
    if state.session == .clipboard {
      model.enterClipboard(query: state.query)
    } else if let mode = model.modes.first(where: { $0.id == state.modeID }) {
      model.enter(mode: mode, query: state.query)
    } else {
      model.query = state.query
    }
  }
}

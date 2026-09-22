import SwiftUI

/// Keyboard focus inside Settings. Sidebar rows and the open pane's controls share one order.
enum SettingsFocusTarget: Hashable {
  case sidebar(SettingsPaneID)
  case control(String)

  var report: String {
    switch self {
    case let .sidebar(pane):
      "sidebar:\(pane.rawValue)"
    case let .control(id):
      "content:\(id)"
    }
  }

  static func order(pane: SettingsPaneID) -> [SettingsFocusTarget] {
    let sidebar = SettingsPaneID.allCases.map { SettingsFocusTarget.sidebar($0) }
    return sidebar + content(for: pane).map { SettingsFocusTarget.control($0) }
  }

  private static func content(for pane: SettingsPaneID) -> [String] {
    switch pane {
    case .general:
      ["general.keyboardSettings", "general.launchAtLogin", "general.replayOnboarding"]
    case .appearance:
      ["appearance.suggestions", "appearance.width", "appearance.reset", "appearance.mode"]
    case .clipboard:
      ["clipboard.enabled", "clipboard.retention", "clipboard.maxItems"]
    case .notes:
      ["notes.size", "notes.float", "notes.launch"]
    case .files:
      ["files.scope", "files.contents", "files.maxResults"]
    case .keybinds:
      ["keybinds.hyper", "keybinds.accessibility"]
    case .about:
      ["about.repository"]
    }
  }
}

extension Notification.Name {
  static let photonSettingsMoveFocus = Notification.Name("photon.settings.moveFocus")
}

enum SettingsFocusRouting {
  static func move(forward: Bool) {
    NotificationCenter.default.post(
      name: .photonSettingsMoveFocus,
      object: nil,
      userInfo: ["forward": forward]
    )
  }

  static func reset() {
    NotificationCenter.default.post(
      name: .photonSettingsMoveFocus,
      object: nil,
      userInfo: ["reset": true]
    )
  }

  static func focus(report: String) {
    NotificationCenter.default.post(
      name: .photonSettingsMoveFocus,
      object: nil,
      userInfo: ["target": report]
    )
  }
}

extension SettingsFocusTarget {
  static func parsed(_ report: String) -> SettingsFocusTarget? {
    if report.hasPrefix("sidebar:") {
      let raw = String(report.dropFirst("sidebar:".count))
      if let pane = SettingsPaneID(rawValue: raw) {
        return .sidebar(pane)
      }
    }
    if report.hasPrefix("content:") {
      return .control(String(report.dropFirst("content:".count)))
    }
    return nil
  }
}

@MainActor
final class SettingsFocusModel: ObservableObject {
  @Published var target: SettingsFocusTarget?

  var report: String {
    target?.report ?? ""
  }
}

extension EnvironmentValues {
  @Entry var settingsFocus: FocusState<SettingsFocusTarget?>.Binding?
}

extension View {
  /// Puts a Settings control on the shared Tab order.
  func settingsFocused(_ target: SettingsFocusTarget) -> some View {
    modifier(SettingsFocusedModifier(target: target))
  }
}

private struct SettingsFocusedModifier: ViewModifier {
  let target: SettingsFocusTarget
  @Environment(\.settingsFocus) private var focus

  func body(content: Content) -> some View {
    if let focus {
      content.focused(focus, equals: target)
    } else {
      content
    }
  }
}

import Foundation

enum OnboardingPermission: String, Equatable, CaseIterable {
  case accessibility
  case inputMonitoring

  var title: String {
    switch self {
    case .accessibility:
      "Accessibility"
    case .inputMonitoring:
      "Input Monitoring"
    }
  }

  var symbol: String {
    switch self {
    case .accessibility:
      "accessibility"
    case .inputMonitoring:
      "keyboard"
    }
  }

  var reason: String {
    switch self {
    case .accessibility:
      "Photon uses this to paste, to run the Hyper key, and to move windows."
    case .inputMonitoring:
      "Photon uses this to hear the launcher shortcut while another app is in front."
    }
  }

  /// Sits under Skip for now so the trade-off is visible before choosing.
  var skipNote: String {
    switch self {
    case .accessibility:
      "Without it, paste, the Hyper key, and window management will not work."
    case .inputMonitoring:
      "Without it, the launcher shortcut may not open Photon from other apps."
    }
  }

  /// Shown after Skip or a denial, then the sequence moves on.
  var withheld: String {
    switch self {
    case .accessibility:
      "Paste, the Hyper key, and window management will not work."
    case .inputMonitoring:
      "The launcher shortcut may not open Photon from other apps."
    }
  }
}

enum OnboardingFeature: String, Equatable, CaseIterable {
  case search
  case suggestions
  case clipboard
  case notes
  case files
  case settings

  var title: String {
    switch self {
    case .search: "Search"
    case .suggestions: "Suggestions"
    case .clipboard: "Clipboard"
    case .notes: "Notes"
    case .files: "Files"
    case .settings: "Settings"
    }
  }

  var symbol: String {
    switch self {
    case .search: "magnifyingglass"
    case .suggestions: "sparkles"
    case .clipboard: "doc.on.clipboard"
    case .notes: "note.text"
    case .files: "folder"
    case .settings: "gearshape"
    }
  }

  var body: String {
    switch self {
    case .search:
      "Type a few letters and apps, clipboard, notes, and files come up together."
    case .suggestions:
      "The apps you open most sit at the top, with a dot on one that is running."
    case .clipboard:
      "Copies stay searchable, and Return pastes the one you have selected."
    case .notes:
      "Write a line and it stays on this Mac, ready from the launcher."
    case .files:
      "File names in your home folder mix into the same list."
    case .settings:
      "Press ⌘, for the hotkey, clipboard, notes, files, and keybinds."
    }
  }
}

enum OnboardingStep: Equatable {
  case reveal
  case permission(OnboardingPermission)
  case feature(OnboardingFeature)
  case tryIt

  var title: String {
    switch self {
    case .reveal:
      "Photon"
    case let .permission(kind):
      kind.title
    case let .feature(kind):
      kind.title
    case .tryIt:
      "Press it to open Photon"
    }
  }

  var token: String {
    switch self {
    case .reveal:
      "reveal"
    case let .permission(kind):
      "permission-\(kind.rawValue)"
    case let .feature(kind):
      "feature-\(kind.rawValue)"
    case .tryIt:
      "try-it"
    }
  }

  var isPermission: Bool {
    if case .permission = self {
      return true
    }
    return false
  }

  var isFeature: Bool {
    if case .feature = self {
      return true
    }
    return false
  }

  static let sequence: [OnboardingStep] = [
    .reveal,
    .permission(.accessibility),
    .permission(.inputMonitoring),
    .feature(.search),
    .feature(.suggestions),
    .feature(.clipboard),
    .feature(.notes),
    .feature(.files),
    .feature(.settings),
    .tryIt,
  ]

  var next: OnboardingStep? {
    guard let index = Self.sequence.firstIndex(of: self) else {
      return nil
    }
    let following = Self.sequence.index(after: index)
    guard following < Self.sequence.endIndex else {
      return nil
    }
    return Self.sequence[following]
  }

  /// Position among the steps after the reveal, for the progress dots.
  var progressIndex: Int? {
    guard self != .reveal, let index = Self.sequence.firstIndex(of: self) else {
      return nil
    }
    return index - 1
  }

  static var progressCount: Int {
    sequence.count - 1
  }
}

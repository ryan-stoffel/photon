import AppKit
import Carbon
import PhotonCore
import SwiftUI

enum OnboardingPractice: Equatable {
  case none
  case launcherShortcut
  case search
  case clipboard
  case note
  case files
  case settingsShortcut
}

enum OnboardingStep: Int, CaseIterable, Equatable {
  case welcome
  case launcher
  case suggestions
  case search
  case clipboard
  case notes
  case files
  case settings

  var title: String {
    switch self {
    case .welcome: "Photon"
    case .launcher: "Open from anywhere"
    case .suggestions: "Suggestions"
    case .search: "Search"
    case .clipboard: "Clipboard"
    case .notes: "Notes"
    case .files: "Files"
    case .settings: "Settings"
    }
  }

  var kicker: String? {
    switch self {
    case .welcome: nil
    case .launcher: "Launcher"
    case .suggestions: "Most used"
    case .search: "One list"
    case .clipboard: "Recent copies"
    case .notes: "Quick notes"
    case .files: "Home folder"
    case .settings: "Anytime"
    }
  }

  var body: String {
    switch self {
    case .welcome:
      "A short tour you can try. Open Photon, search, and use the pieces that stay on this Mac."
    case .launcher:
      "Press this shortcut with the tour focused. Photon comes up over whatever you are doing."
    case .suggestions:
      "The apps you open most sit at the top. A dot marks one that is running, wherever it sits."
    case .search:
      "Type a few letters. Apps, clipboard, notes, and files come up together."
    case .clipboard:
      "Search finds what you copied. Return pastes the one you have selected."
    case .notes:
      "Write a line. The note stays searchable from the launcher."
    case .files:
      "Names in your home folder mix into the same list. Try ember."
    case .settings:
      "Press ⌘, for the hotkey, clipboard, notes, files, and keybinds."
    }
  }

  var practice: OnboardingPractice {
    switch self {
    case .welcome, .suggestions: .none
    case .launcher: .launcherShortcut
    case .search: .search
    case .clipboard: .clipboard
    case .notes: .note
    case .files: .files
    case .settings: .settingsShortcut
    }
  }

  var continues: String {
    self == .settings ? "Start using Photon" : "Continue"
  }

  var triesText: Bool {
    switch practice {
    case .search, .note, .files: true
    case .none, .launcherShortcut, .clipboard, .settingsShortcut: false
    }
  }

  var next: OnboardingStep? {
    OnboardingStep(rawValue: rawValue + 1)
  }

  var previous: OnboardingStep? {
    OnboardingStep(rawValue: rawValue - 1)
  }
}

@MainActor
final class OnboardingController: ObservableObject {
  @Published var step: OnboardingStep = .welcome
  @Published var hotkey: HotkeyCombo
  @Published var practiceQuery = ""
  @Published var noteDraft = ""
  @Published var clipboardPasted = false
  @Published var shortcutLanded = false
  var onFinish: (() -> Void)?

  private var window: OnboardingWindow?
  private var keyMonitor: Any?
  private var advanceTask: Task<Void, Never>?

  init(hotkey: HotkeyCombo) {
    self.hotkey = hotkey
  }

  var isVisible: Bool {
    window?.isVisible == true
  }

  var windowNumber: Int {
    window?.windowNumber ?? 0
  }

  func present(hotkey: HotkeyCombo) {
    self.hotkey = hotkey
    resetPractice()
    step = .welcome
    if window == nil {
      let host = NSHostingView(rootView: AnyView(OnboardingView(model: self)))
      window = OnboardingChrome.makeWindow(host: host)
    }
    installKeyMonitor()
    NSApp.activate(ignoringOtherApps: true)
    window?.center()
    window?.makeKeyAndOrderFront(nil)
  }

  func advance() {
    advanceTask?.cancel()
    if let next = step.next {
      withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
        step = next
        resetPractice()
      }
    } else {
      finish()
    }
  }

  func retreat() {
    guard let previous = step.previous else {
      return
    }
    advanceTask?.cancel()
    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
      step = previous
      resetPractice()
    }
  }

  func finish() {
    advanceTask?.cancel()
    removeKeyMonitor()
    FirstLaunch.markInteractiveOnboardingComplete()
    window?.orderOut(nil)
    let callback = onFinish
    onFinish = nil
    callback?()
  }

  func handleKey(_ event: NSEvent) -> Bool {
    switch step.practice {
    case .launcherShortcut:
      guard eventMatches(event, combo: hotkey) else {
        return false
      }
      landShortcut()
      return true
    case .settingsShortcut:
      guard eventMatchesCommandComma(event) else {
        return false
      }
      landShortcut()
      return true
    case .clipboard:
      guard event.keyCode == UInt16(kVK_Return) || event.keyCode == UInt16(kVK_ANSI_KeypadEnter) else {
        return false
      }
      withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        clipboardPasted = true
      }
      return true
    case .none, .search, .note, .files:
      return false
    }
  }

  private func landShortcut() {
    withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
      shortcutLanded = true
    }
    advanceTask?.cancel()
    advanceTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(560))
      guard !Task.isCancelled, shortcutLanded else {
        return
      }
      advance()
    }
  }

  private func eventMatches(_ event: NSEvent, combo: HotkeyCombo) -> Bool {
    UInt32(event.keyCode) == combo.keyCode && eventCarbonModifiers(event) == combo.carbonModifiers
  }

  private func eventMatchesCommandComma(_ event: NSEvent) -> Bool {
    event.keyCode == UInt16(kVK_ANSI_Comma) && eventCarbonModifiers(event) == UInt32(cmdKey)
  }

  private func eventCarbonModifiers(_ event: NSEvent) -> UInt32 {
    HotkeyCombo.carbonModifiers(fromApple: UInt32(event.modifierFlags.rawValue))
  }

  private func resetPractice() {
    practiceQuery = ""
    noteDraft = ""
    clipboardPasted = false
    shortcutLanded = false
  }

  private func installKeyMonitor() {
    guard keyMonitor == nil else {
      return
    }
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      MainActor.assumeIsolated {
        guard let self else {
          return event
        }
        return handleKey(event) ? nil : event
      }
    }
  }

  private func removeKeyMonitor() {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
    }
    keyMonitor = nil
  }
}

enum OnboardingChrome {
  static let windowSize = NSSize(width: 640, height: 600)

  @MainActor
  static func makeWindow(host: NSHostingView<AnyView>) -> OnboardingWindow {
    host.safeAreaRegions = []
    host.sizingOptions = []
    host.frame = NSRect(origin: .zero, size: windowSize)
    let window = OnboardingWindow(
      contentRect: NSRect(origin: .zero, size: windowSize),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = "Photon"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.isMovableByWindowBackground = true
    window.setContentSize(windowSize)
    let chrome = PhotonPanelChrome.embed(
      host,
      frame: NSRect(origin: .zero, size: windowSize),
      cornerRadius: LauncherLayout.cornerRadius,
      material: .popover
    )
    chrome.identifier = NSUserInterfaceItemIdentifier("photon.onboarding")
    window.contentView = chrome
    window.hostingView = host
    return window
  }
}

final class OnboardingWindow: NSWindow {
  var hostingView: NSHostingView<AnyView>?

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }
}

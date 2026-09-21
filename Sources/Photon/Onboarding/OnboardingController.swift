import AppKit
import PhotonCore
import SwiftUI

enum OnboardingStep: Int, CaseIterable, Equatable {
  case welcome
  case launcher
  case suggestions
  case search
  case settings

  var title: String {
    switch self {
    case .welcome: "Photon"
    case .launcher: "Open from anywhere"
    case .suggestions: "Suggestions"
    case .search: "Search"
    case .settings: "Settings"
    }
  }

  var kicker: String? {
    switch self {
    case .welcome: nil
    case .launcher: "Launcher"
    case .suggestions: "Most used"
    case .search: "One list"
    case .settings: "Anytime"
    }
  }

  var body: String {
    switch self {
    case .welcome:
      "A short look at opening apps, clipboard, notes, and files without leaving the keyboard."
    case .launcher:
      "This brings Photon up. Change the shortcut later if you want a different one."
    case .suggestions:
      "The apps you open most sit at the top. A small dot marks one that is running, wherever it sits."
    case .search:
      "Type a few letters. Apps, files, and notes come up together."
    case .settings:
      "Press ⌘, for the hotkey, clipboard, notes, files, and keybinds."
    }
  }

  var continues: String {
    self == .settings ? "Start using Photon" : "Continue"
  }

  var next: OnboardingStep? {
    OnboardingStep(rawValue: rawValue + 1)
  }
}

@MainActor
final class OnboardingController: ObservableObject {
  @Published var step: OnboardingStep = .welcome
  @Published var hotkey: HotkeyCombo
  var onFinish: (() -> Void)?

  private var window: OnboardingWindow?

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
    step = .welcome
    if window == nil {
      let host = NSHostingView(rootView: AnyView(OnboardingView(model: self)))
      window = OnboardingChrome.makeWindow(host: host)
    }
    NSApp.activate(ignoringOtherApps: true)
    window?.center()
    window?.makeKeyAndOrderFront(nil)
  }

  func advance() {
    if let next = step.next {
      step = next
    } else {
      finish()
    }
  }

  func finish() {
    UserDefaults.standard.set(true, forKey: FirstLaunch.onboardingKey)
    window?.orderOut(nil)
    let callback = onFinish
    onFinish = nil
    callback?()
  }
}

enum OnboardingChrome {
  static let windowSize = NSSize(width: 560, height: 460)

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

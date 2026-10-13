import AppKit
import SwiftUI

@main
struct PhotonApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsRootView(settings: appDelegate.runtime.settings)
        .environmentObject(appDelegate.runtime.settings)
        .environmentObject(appDelegate.runtime.clipboard)
        .environmentObject(appDelegate.runtime.keybinds)
        .environmentObject(appDelegate.runtime.fileAccess)
        .environmentObject(appDelegate.runtime.runningApps)
        .environmentObject(appDelegate.runtime.settingsFocus)
        .background(PhotonSettingsWindowBinder())
        .frame(minWidth: 720, minHeight: 480)
    }
    .commands {
      CommandGroup(replacing: .appSettings) {
        Button("Settings…") {
          appDelegate.runtime.openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)
      }
    }
  }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  let runtime = AppRuntime()
  private(set) var statusItemController: StatusItemController?
  private var signalSources: [DispatchSourceSignal] = []

  func applicationDidFinishLaunching(_: Notification) {
    NSApp.setActivationPolicy(.accessory)
    PhotonAppIcon.install()
    installMainMenu()
    terminateOnSignals()
    statusItemController = StatusItemController(runtime: runtime)
    runtime.start()
    runtime.runUIScenarioIfNeeded()
    NativeParityReporter.startIfRequested(runtime: runtime, statusItem: statusItemController)
  }

  func application(_: NSApplication, open urls: [URL]) {
    runtime.openNotes(from: urls)
  }

  func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
    false
  }

  func applicationWillTerminate(_: Notification) {
    NativeParityReporter.stop()
    runtime.stop()
  }

  /// Replaces SwiftUI's main menu. Edit and Window items have nil targets, so ⌘C, ⌘V and ⌘W
  /// reach whichever Photon window is key.
  private func installMainMenu() {
    let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsMenu), keyEquivalent: ",")
    settingsItem.target = self
    let mainMenu = NSMenu()
    mainMenu.addItem(submenu(PhotonProduct.displayName, [settingsItem]))
    mainMenu.addItem(submenu("Edit", [
      NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"),
      NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z"),
      .separator(),
      NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"),
      NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"),
      NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"),
      NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"),
    ]))
    mainMenu.addItem(submenu("Window", [
      NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"),
      NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"),
    ]))
    NSApp.mainMenu = mainMenu
  }

  private func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let menu = NSMenu(title: title)
    items.forEach(menu.addItem)
    let item = NSMenuItem()
    item.submenu = menu
    return item
  }

  /// SIGTERM and SIGINT (pkill, Ctrl-C) quit through `NSApp.terminate`, so `applicationWillTerminate`
  /// still restores the Caps Lock remap.
  private func terminateOnSignals() {
    for sig in [SIGTERM, SIGINT] {
      signal(sig, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: sig, queue: .main)
      source.setEventHandler {
        MainActor.assumeIsolated {
          NSApp.terminate(nil)
        }
      }
      source.resume()
      signalSources.append(source)
    }
  }

  @objc private func openSettingsMenu() {
    runtime.openSettings()
  }
}

@MainActor
final class StatusItemController: NSObject {
  let statusItem: NSStatusItem
  private let runtime: AppRuntime
  private var appearanceObserver: NSObjectProtocol?

  init(runtime: AppRuntime) {
    self.runtime = runtime
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()

    let name = PhotonProduct.displayName
    if let button = statusItem.button {
      applyStatusImage(to: button)
      button.toolTip = name
      DispatchQueue.main.async { [weak self, weak button] in
        guard let self, let button else { return }
        applyStatusImage(to: button)
      }
    }
    if PhotonProduct.isDev {
      appearanceObserver = DistributedNotificationCenter.default().addObserver(
        forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          guard let button = self?.statusItem.button else { return }
          self?.applyStatusImage(to: button)
        }
      }
    }

    let menu = NSMenu(title: name)
    menu.addItem(item("Open Launcher", action: #selector(openLauncher)))
    menu.addItem(item("Clipboard History", action: #selector(openClipboard)))
    menu.addItem(item("Notes", action: #selector(openNotes)))
    let settingsItem = item("Settings…", action: #selector(openSettings))
    settingsItem.keyEquivalent = ","
    settingsItem.keyEquivalentModifierMask = .command
    menu.addItem(settingsItem)
    menu.addItem(.separator())
    menu.addItem(item("Quit \(name)", action: #selector(quit)))
    statusItem.menu = menu
  }

  private func applyStatusImage(to button: NSStatusBarButton) {
    let points = button.bounds.height > 1 ? button.bounds.height : 22
    let scale = button.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    button.image = MenuBarStatusImage.make(
      devBadge: PhotonProduct.isDev,
      appearance: button.effectiveAppearance,
      points: points,
      scale: scale
    )
  }

  private func item(_ title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  /// Brings an open launcher forward without resetting its query or mode.
  @objc private func openLauncher() {
    let launcher = runtime.launcher
    if let panel = launcher.panel, panel.isVisible, launcher.model.session == .commands {
      panel.makeKey()
      launcher.model.requestSearchFocus()
      return
    }
    launcher.show()
  }

  /// Unlike the hotkey, the menu item never closes clipboard history that is already showing.
  @objc private func openClipboard() {
    let launcher = runtime.launcher
    if launcher.panel?.isVisible == true, launcher.model.session == .clipboard {
      return
    }
    runtime.showClipboardHistory()
  }

  @objc private func openNotes() {
    runtime.toggleNotes()
  }

  @objc private func openSettings() {
    runtime.openSettings()
  }

  @objc private func quit() {
    NSApp.terminate(nil)
  }
}

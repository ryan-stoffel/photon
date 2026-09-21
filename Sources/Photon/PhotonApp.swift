import AppKit
import SwiftUI

@main
struct PhotonApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    Settings {
      SettingsRootView()
        .environmentObject(appDelegate.runtime.settings)
        .environmentObject(appDelegate.runtime.clipboard)
        .environmentObject(appDelegate.runtime.keybinds)
        .environmentObject(appDelegate.runtime.fileAccess)
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

  func applicationDidFinishLaunching(_: Notification) {
    NSApp.setActivationPolicy(.accessory)
    installSettingsMenu()
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

  private func installSettingsMenu() {
    let mainMenu = NSMenu()
    let appItem = NSMenuItem()
    let appMenu = NSMenu(title: "Photon")
    let settingsItem = NSMenuItem(
      title: "Settings…",
      action: #selector(openSettingsMenu),
      keyEquivalent: ","
    )
    settingsItem.target = self
    appMenu.addItem(settingsItem)
    appItem.submenu = appMenu
    mainMenu.addItem(appItem)
    NSApp.mainMenu = mainMenu
  }

  @objc private func openSettingsMenu() {
    runtime.openSettings()
  }
}

@MainActor
final class StatusItemController: NSObject {
  let statusItem: NSStatusItem
  private let runtime: AppRuntime

  init(runtime: AppRuntime) {
    self.runtime = runtime
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    super.init()

    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Photon")
      button.image?.isTemplate = true
      button.toolTip = "Photon"
    }

    let menu = NSMenu(title: "Photon")
    menu.addItem(item("Open Launcher", action: #selector(openLauncher)))
    menu.addItem(item("Clipboard History", action: #selector(openClipboard)))
    menu.addItem(item("Notes", action: #selector(openNotes)))
    let settingsItem = item("Settings…", action: #selector(openSettings))
    settingsItem.keyEquivalent = ","
    settingsItem.keyEquivalentModifierMask = .command
    menu.addItem(settingsItem)
    menu.addItem(.separator())
    menu.addItem(item("Quit Photon", action: #selector(quit)))
    statusItem.menu = menu
  }

  private func item(_ title: String, action: Selector) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
    item.target = self
    return item
  }

  @objc private func openLauncher() {
    runtime.toggleLauncher()
  }

  @objc private func openClipboard() {
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

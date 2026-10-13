import AppKit

@MainActor
enum SpotlightConflict {
  static let spotlightHotKeyID = "64"
  private static let shownKey = "hasShownSpotlightGuidance"

  /// Spotlight's entry in the symbolic hotkeys plist. A Mac that never changed it has none and uses ⌘Space.
  private static var spotlightEntry: NSDictionary? {
    let url = URL(
      fileURLWithPath: NSHomeDirectory() + "/Library/Preferences/com.apple.symbolichotkeys.plist"
    )
    let keys = NSDictionary(contentsOf: url)?["AppleSymbolicHotKeys"] as? NSDictionary
    return keys?[spotlightHotKeyID] as? NSDictionary
  }

  /// Like `conflicts(with:)`, but a missing plist entry counts as Spotlight's stock ⌘Space. The welcome uses it.
  static func likelyConflicts(with combo: HotkeyCombo) -> Bool {
    spotlightEntry == nil ? combo == .defaultCombo : conflicts(with: combo)
  }

  static func conflicts(with combo: HotkeyCombo) -> Bool {
    guard let spotlight = spotlightEntry,
          (spotlight["enabled"] as? Bool) == true,
          let value = spotlight["value"] as? NSDictionary,
          let parameters = value["parameters"] as? [Any],
          parameters.count >= 3
    else {
      return false
    }

    let keyCode = intValue(parameters[1])
    let modifiers = UInt32(truncatingIfNeeded: intValue(parameters[2]))
    guard keyCode == Int(combo.keyCode) else {
      return false
    }

    if modifiers == combo.carbonModifiers {
      return true
    }
    if modifiers == combo.appleFlags {
      return true
    }
    if HotkeyCombo.carbonModifiers(fromApple: modifiers) == combo.carbonModifiers {
      return true
    }
    return false
  }

  static func adviseIfNeeded(current combo: HotkeyCombo) {
    let defaults = UserDefaults.standard
    guard !defaults.bool(forKey: shownKey) else {
      return
    }
    defaults.set(true, forKey: shownKey)
    guard conflicts(with: combo) else {
      return
    }

    let alert = NSAlert()
    alert.messageText = "Photon and Spotlight share the same shortcut"
    alert.informativeText = """
    Photon defaults to \(combo.displayString), which is also Spotlight’s shortcut.

    To use Photon without a fight:
    1. Open System Settings > Keyboard > Keyboard Shortcuts
    2. Select Spotlight
    3. Uncheck “Show Spotlight search”

    You can change Photon’s shortcut later in Settings > General.
    """
    alert.alertStyle = .informational
    alert.addButton(withTitle: "Open Keyboard Settings")
    alert.addButton(withTitle: "Later")
    let response = alert.runModal()
    if response == .alertFirstButtonReturn {
      openKeyboardSettings()
    }
  }

  /// Stops `adviseIfNeeded` from showing its alert, for when the welcome already covered the conflict.
  static func markShown() {
    UserDefaults.standard.set(true, forKey: shownKey)
  }

  static func openKeyboardSettings() {
    let urls = [
      "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?Shortcuts",
      "x-apple.systempreferences:com.apple.preference.keyboard?Shortcuts"
    ]
    for string in urls {
      if let url = URL(string: string), NSWorkspace.shared.open(url) {
        return
      }
    }
  }

  private static func intValue(_ value: Any) -> Int {
    if let number = value as? NSNumber {
      return number.intValue
    }
    if let int = value as? Int {
      return int
    }
    return -1
  }
}

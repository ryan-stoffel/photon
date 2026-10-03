import Foundation

/// Human-readable titles and searchable aliases for System Settings panes: built-in Settings extensions
/// (`.appex`) and third-party `.prefPane` bundles.
public enum SystemSettingsPaneMetadata: Sendable {
  /// Title for a built-in Settings extension, or nil to skip it. A few extensions ship only an internal name.
  public static func extensionTitle(bundleIdentifier: String, localizedName: String?) -> String? {
    if let title = extensionTitleOverrides[bundleIdentifier] {
      return title
    }
    guard !skippedExtensions.contains(bundleIdentifier), let localizedName, !localizedName.isEmpty else {
      return nil
    }
    return localizedName
  }

  /// English only, and desktop Macs label this pane "Energy". Read the extension's
  /// `representations` if that matters.
  private static let extensionTitleOverrides = ["com.apple.Battery-Settings.extension": "Battery"]

  /// Extensions without a user-facing name. HeadphoneSettings only has a pane while headphones are connected.
  private static let skippedExtensions: Set = ["com.apple.HeadphoneSettings"]

  /// Resolves the title shown in the launcher, preferring localized bundle metadata.
  public static func displayName(
    info: [String: Any],
    localizedInfo: [String: Any]?,
    fallbackStem: String
  ) -> String {
    for source in [localizedInfo, info].compactMap(\.self) {
      if let name = bundleName(in: source), !name.isEmpty {
        return name
      }
    }
    return humanizeStem(fallbackStem)
  }

  /// Extra terms for fuzzy search: the title, the bundle stem and aliases. Does not affect the row title.
  /// The bundle id only selects aliases, so "cal" does not match every com.apple pane.
  public static func searchKeywords(
    displayName: String,
    bundleIdentifier: String,
    fallbackStem: String
  ) -> [String] {
    var terms = Set<String>()
    terms.insert(fallbackStem)
    terms.insert(displayName)
    // One combined term, so "settings" reaches every pane through the fuzzy keyword tier
    // and the System Settings app still ranks first on its title.
    terms.insert("System Settings Preferences")

    let idLower = bundleIdentifier.lowercased()
    let stemLower = fallbackStem.lowercased()
    for (key, aliases) in aliasTable {
      let keyLower = key.lowercased()
      if idLower.contains(keyLower) || stemLower.contains(keyLower) {
        for alias in aliases {
          terms.insert(alias)
        }
      }
    }
    return Array(terms)
  }

  private static func bundleName(in info: [String: Any]) -> String? {
    if let name = info["CFBundleDisplayName"] as? String, !name.isEmpty {
      return name
    }
    if let name = info["CFBundleName"] as? String, !name.isEmpty {
      return name
    }
    return nil
  }

  /// Maps bundle-id fragments or bundle stems to extra search terms.
  private static let aliasTable: [String: [String]] = [
    "wallpaper": ["wallpaper", "background", "screen saver", "screensaver"],
    "privacysecurity": ["privacy", "privacy & security", "security"],
    "battery": ["battery", "power", "energy"],
    "bluetooth": ["bluetooth"],
    "network-settings": ["network", "ethernet"],
    "wifi": ["wifi", "wi-fi", "wireless"],
    "sound": ["sound", "volume", "audio"],
    "displays": ["display", "monitor", "screen"],
    "keyboard": ["keyboard"],
    "trackpad": ["trackpad"],
    "mouse": ["mouse"],
    "spotlight": ["spotlight", "search"],
    "softwareupdate": ["update", "updates", "software update"],
    "sharing": ["sharing", "airdrop"],
    "accessibility": ["accessibility", "a11y"],
    "users": ["users", "groups"],
    "timemachine": ["backup", "time machine"],
    "notifications": ["notifications", "alerts"],
    "internetaccounts": ["accounts", "mail", "icloud"],
    "appleid": ["apple id", "icloud account"],
    "wallet": ["wallet", "apple pay"],
    "appearance": ["appearance", "theme", "dark mode", "light mode"],
    "localization": ["language", "region"],
    "screentime": ["screen time", "parental"],
    "gamecontroller": ["controller", "gamepad"],
    "print": ["printer", "printers", "scanner"],
    "startupdisk": ["startup", "boot"],
    "dateandtime": ["date", "time", "clock"],
  ]

  private static func humanizeStem(_ stem: String) -> String {
    var text = stem
    if text.hasSuffix("Pref") {
      text = String(text.dropLast(4))
    }
    var words: [String] = []
    var current = ""
    for character in text {
      if character.isUppercase, !current.isEmpty {
        words.append(current)
        current = String(character)
      } else {
        current.append(character)
      }
    }
    if !current.isEmpty {
      words.append(current)
    }
    return words.joined(separator: " ")
  }
}

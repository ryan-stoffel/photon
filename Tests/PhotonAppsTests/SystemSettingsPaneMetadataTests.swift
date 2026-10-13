import PhotonApps
import XCTest

final class SystemSettingsPaneMetadataTests: XCTestCase {
  func testLocalizedInfoPlistDisplayNameWinsOverStem() {
    let name = SystemSettingsPaneMetadata.displayName(
      info: ["CFBundleName": "DesktopScreenSaverPref"],
      localizedInfo: ["CFBundleName": "Wallpaper"],
      fallbackStem: "DesktopScreenSaverPref"
    )
    XCTAssertEqual(name, "Wallpaper")
  }

  func testCFBundleDisplayNamePreferredOverCFBundleName() {
    let name = SystemSettingsPaneMetadata.displayName(
      info: [
        "CFBundleDisplayName": "Privacy & Security",
        "CFBundleName": "SecurityPref",
      ],
      localizedInfo: nil,
      fallbackStem: "SecurityPref"
    )
    XCTAssertEqual(name, "Privacy & Security")
  }

  func testStemIsHumanizedWhenPlistEmpty() {
    XCTAssertEqual(
      SystemSettingsPaneMetadata.displayName(info: [:], localizedInfo: nil, fallbackStem: "SharingPref"),
      "Sharing"
    )
    XCTAssertEqual(
      SystemSettingsPaneMetadata.displayName(info: [:], localizedInfo: nil, fallbackStem: "EnergySaverPref"),
      "Energy Saver"
    )
  }

  func testExtensionTitleUsesTheLocalizedNameWithOverrides() {
    let title = SystemSettingsPaneMetadata.extensionTitle(bundleIdentifier:localizedName:)
    XCTAssertEqual(title("com.apple.wifi-settings-extension", "Wi\u{2011}Fi"), "Wi\u{2011}Fi")
    XCTAssertEqual(title("com.apple.Battery-Settings.extension", "PowerPreferences"), "Battery")
    XCTAssertNil(title("com.apple.HeadphoneSettings", "HeadphoneSettingsExtension"))
    XCTAssertNil(title("com.apple.Example-Settings.extension", nil))
  }

  func testKeywordsLeaveOutTheBundleIdentifierAndShareOneSettingsTerm() {
    let keywords = SystemSettingsPaneMetadata.searchKeywords(
      displayName: "Bluetooth",
      bundleIdentifier: "com.apple.BluetoothSettings",
      fallbackStem: "Bluetooth"
    )
    XCTAssertFalse(keywords.contains("com.apple.BluetoothSettings"))
    XCTAssertTrue(keywords.contains("System Settings Preferences"))
    XCTAssertFalse(keywords.contains { $0.caseInsensitiveCompare("settings") == .orderedSame })
  }

  func testWallpaperAliasIncludesScreenSaver() {
    let keywords = SystemSettingsPaneMetadata.searchKeywords(
      displayName: "Wallpaper",
      bundleIdentifier: "com.apple.Wallpaper-Settings.extension",
      fallbackStem: "Wallpaper"
    )
    XCTAssertTrue(keywords.contains("screen saver"))
  }

  func testPrivacyAliasMatchesOnlyThePrivacyPane() {
    let keywords = SystemSettingsPaneMetadata.searchKeywords(
      displayName: "Privacy & Security",
      bundleIdentifier: "com.apple.settings.PrivacySecurity.extension",
      fallbackStem: "SecurityPrivacyExtension"
    )
    XCTAssertTrue(keywords.contains { $0.caseInsensitiveCompare("privacy") == .orderedSame })
    XCTAssertTrue(keywords.contains { $0.caseInsensitiveCompare("privacy & security") == .orderedSame })

    let improvements = SystemSettingsPaneMetadata.searchKeywords(
      displayName: "Background Security Improvements",
      bundleIdentifier: "com.apple.SecurityImprovements-Settings.extension",
      fallbackStem: "SecurityImprovementsExtension"
    )
    XCTAssertFalse(improvements.contains("privacy"))
  }

  func testFixturePanePlistFromStringsTable() {
    let fixtureInfo: [String: Any] = [:]
    let fixtureLocalized: [String: Any] = [
      "CFBundleName": "Bluetooth",
    ]
    let name = SystemSettingsPaneMetadata.displayName(
      info: fixtureInfo,
      localizedInfo: fixtureLocalized,
      fallbackStem: "BluetoothPref"
    )
    XCTAssertEqual(name, "Bluetooth")
    let keywords = SystemSettingsPaneMetadata.searchKeywords(
      displayName: name,
      bundleIdentifier: "com.apple.preferences.BluetoothPref",
      fallbackStem: "BluetoothPref"
    )
    XCTAssertTrue(keywords.contains { $0.caseInsensitiveCompare("bluetooth") == .orderedSame })
  }
}

import AppKit
import Foundation
import PhotonCore

public struct IndexedApplication: Hashable, Sendable {
  public let id: String
  public let name: String
  public let subtitle: String
  /// What opening the row opens: an `.app` or `.prefPane` bundle, or a System Settings URL for built-in panes.
  public let url: URL
  public let keywords: [String]
  public let icon: CommandIcon
}

public final class ApplicationIndex: @unchecked Sendable {
  private let lock = NSLock()
  private var items: [IndexedApplication] = []

  public init() {}

  public var applications: [IndexedApplication] {
    lock.lock()
    defer { lock.unlock() }
    return items
  }

  public func refresh() {
    var found: [IndexedApplication] = []
    found.reserveCapacity(128)

    let homeApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
    let roots = [
      URL(fileURLWithPath: "/Applications", isDirectory: true),
      URL(fileURLWithPath: "/System/Applications", isDirectory: true),
      homeApps
    ]
    for root in roots {
      collectApps(at: root, depth: 2, into: &found)
    }
    // Keychain Access, Archive Utility and the other system utilities.
    let coreServicesApps = URL(fileURLWithPath: "/System/Library/CoreServices/Applications", isDirectory: true)
    collectApps(at: coreServicesApps, depth: 0, into: &found)
    if let extra = ProcessInfo.processInfo.environment["PHOTON_APPLICATIONS_EXTRA"] {
      for segment in extra.split(separator: ":") where !segment.isEmpty {
        collectApps(at: URL(fileURLWithPath: String(segment), isDirectory: true), depth: 2, into: &found)
      }
    }

    collectSettingsPanes(into: &found)
    // Third-party panes. The built-in /System/Library/PreferencePanes bundles are empty stubs on current macOS.
    let paneRoots = [
      URL(fileURLWithPath: "/Library/PreferencePanes", isDirectory: true),
      FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/PreferencePanes")
    ]
    for root in paneRoots {
      collectPanes(at: root, into: &found)
    }
    includeSystemFinder(into: &found)

    // Two copies of one bundle id (Xcode and Xcode-beta) would share a row id. The first root scanned wins.
    var seenIDs = Set<String>()
    found = found.filter { seenIDs.insert($0.id).inserted }

    found.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    lock.lock()
    items = found
    lock.unlock()
  }

  /// Finder.app lives in CoreServices, outside `/Applications` and `/System/Applications`.
  private func includeSystemFinder(into found: inout [IndexedApplication]) {
    let alreadyIndexed = found.contains {
      $0.id.caseInsensitiveCompare("app:com.apple.finder") == .orderedSame
    }
    guard !alreadyIndexed else {
      return
    }
    let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app", isDirectory: true)
    guard FileManager.default.fileExists(atPath: url.path), let finder = readApp(at: url) else {
      return
    }
    found.append(finder)
  }

  private func collectApps(at root: URL, depth: Int, into found: inout [IndexedApplication]) {
    guard depth >= 0 else {
      return
    }
    let fm = FileManager.default
    // Dot files are skipped by name, not `.skipsHiddenFiles`: macOS 27 flags the /Applications/Safari.app link hidden.
    guard let children = try? fm.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: []
    ) else {
      return
    }
    for url in children where !url.lastPathComponent.hasPrefix(".") {
      if url.pathExtension == "app" {
        if let app = readApp(at: url) {
          found.append(app)
        }
      } else if depth > 0 {
        collectApps(at: url, depth: depth - 1, into: &found)
      }
    }
  }

  private func collectPanes(at root: URL, into found: inout [IndexedApplication]) {
    let fm = FileManager.default
    guard let children = try? fm.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return
    }
    for url in children where url.pathExtension == "prefPane" {
      if let pane = readPane(at: url) {
        found.append(pane)
      }
    }
  }

  /// Built-in System Settings panes: the Settings extensions that System Settings opens by URL.
  private func collectSettingsPanes(into found: inout [IndexedApplication]) {
    let root = URL(fileURLWithPath: "/System/Library/ExtensionKit/Extensions", isDirectory: true)
    guard let children = try? FileManager.default.contentsOfDirectory(
      at: root,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    ) else {
      return
    }
    var seenTitles = Set<String>()
    for url in children where url.pathExtension == "appex" {
      if let pane = readSettingsPane(at: url), seenTitles.insert(pane.name).inserted {
        found.append(pane)
      }
    }
  }

  private func readSettingsPane(at url: URL) -> IndexedApplication? {
    guard let bundle = Bundle(url: url),
          let identifier = bundle.bundleIdentifier,
          let info = bundle.infoDictionary,
          let attributes = info["EXAppExtensionAttributes"] as? [String: Any],
          attributes["EXExtensionPointIdentifier"] as? String == "com.apple.Settings.extension.ui",
          let settings = attributes["SettingsExtensionAttributes"] as? [String: Any],
          settings["allowsXAppleSystemPreferencesURLScheme"] as? Bool == true,
          let openURL = URL(string: "x-apple.systempreferences:\(identifier)")
    else {
      return nil
    }
    let localizedName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
      ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    guard let name = SystemSettingsPaneMetadata.extensionTitle(
      bundleIdentifier: identifier,
      localizedName: localizedName
    ) else {
      return nil
    }
    return IndexedApplication(
      id: "pane:\(identifier)",
      name: name,
      subtitle: "System Settings",
      url: openURL,
      keywords: SystemSettingsPaneMetadata.searchKeywords(
        displayName: name,
        bundleIdentifier: identifier,
        fallbackStem: url.deletingPathExtension().lastPathComponent
      ),
      icon: PaneIconPolicy.icon(forSettingsExtensionAt: url, info: info)
    )
  }

  private func readApp(at url: URL) -> IndexedApplication? {
    let bundle = Bundle(url: url)
    let names = Self.appNames(
      localizedName: (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName,
      fileName: url.deletingPathExtension().lastPathComponent,
      bundleNames: [
        bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
        bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
      ]
    )
    guard !names.title.isEmpty else {
      return nil
    }
    let identifier = bundle?.bundleIdentifier ?? url.path
    // The launcher shows the name and icon only; the path adds nothing a user needs.
    // The icon path is resolved so a symlinked app (Safari) draws without the alias arrow.
    return IndexedApplication(
      id: "app:\(identifier)",
      name: names.title,
      subtitle: "",
      url: url,
      keywords: names.keywords,
      icon: .fileIcon(path: url.resolvingSymlinksInPath().path)
    )
  }

  /// Finder title (the localized file name without ".app") plus the other names the app goes by.
  /// Keywords never hold the bundle id or path, so "cal" does not match com.apple.Safari.
  static func appNames(
    localizedName: String?,
    fileName: String,
    bundleNames: [String?]
  ) -> (title: String, keywords: [String]) {
    var title = localizedName ?? ""
    if title.hasSuffix(".app") {
      title.removeLast(4)
    }
    if title.isEmpty {
      title = fileName
    }
    var keywords: [String] = []
    for name in [fileName] + bundleNames.compactMap(\.self) where !name.isEmpty {
      let known = ([title] + keywords).contains { $0.caseInsensitiveCompare(name) == .orderedSame }
      if !known {
        keywords.append(name)
      }
    }
    return (title, keywords)
  }

  private func readPane(at url: URL) -> IndexedApplication? {
    let bundle = Bundle(url: url)
    let stem = url.deletingPathExtension().lastPathComponent
    let info = bundle?.infoDictionary ?? [:]
    let name = SystemSettingsPaneMetadata.displayName(
      info: info,
      localizedInfo: bundle?.localizedInfoDictionary,
      fallbackStem: stem
    )
    guard !name.isEmpty else {
      return nil
    }
    let identifier = bundle?.bundleIdentifier ?? url.path
    let keywords = SystemSettingsPaneMetadata.searchKeywords(
      displayName: name,
      bundleIdentifier: identifier,
      fallbackStem: stem
    )
    let icon = PaneIconPolicy.icon(
      forPaneAt: url,
      info: info,
      fileExists: { FileManager.default.fileExists(atPath: $0) }
    )
    return IndexedApplication(
      id: "pane:\(identifier)",
      name: name,
      subtitle: "System Settings",
      url: url,
      keywords: keywords,
      icon: icon
    )
  }
}

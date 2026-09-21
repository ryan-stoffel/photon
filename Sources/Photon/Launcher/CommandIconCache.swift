import AppKit
import PhotonCore

/// What the launcher draws for a command once its `CommandIcon` is resolved.
enum ResolvedCommandIcon {
  case image(NSImage)
  case symbol(String)
}

/// Turns `CommandIcon` values into images, once each.
///
/// Cache hits are synchronous. Misses never load Finder icons on the main
/// thread: the row shows a symbol placeholder and the cache fills in the
/// background. `prefetch` is safe from any thread.
final class CommandIconCache: @unchecked Sendable {
  static let shared = CommandIconCache()
  /// Coalesced UI refresh after a background miss load. Set from the launcher.
  @MainActor
  static var onImagesLoaded: (() -> Void)?

  private let images = NSCache<NSString, NSImage>()
  private let misses = NSCache<NSString, NSNumber>()
  private let inflight = NSLock()
  private var loading = Set<String>()

  init() {
    images.countLimit = 1200
    misses.countLimit = 1200
  }

  /// The declared icon when it resolves, otherwise `fallbackSymbol`.
  func resolve(_ icon: CommandIcon?, fallbackSymbol: String) -> ResolvedCommandIcon {
    if let icon {
      switch icon {
      case let .symbol(name):
        if image(for: icon) != nil {
          return .symbol(name)
        }
      default:
        if let image = image(for: icon) {
          return .image(image)
        }
      }
    }
    return .symbol(fallbackSymbol)
  }

  func image(for icon: CommandIcon) -> NSImage? {
    let key = Self.key(for: icon) as NSString
    if let hit = images.object(forKey: key) {
      return hit
    }
    if misses.object(forKey: key) != nil {
      return nil
    }
    if Thread.isMainThread {
      scheduleLoad(icon, key: key as String)
      return nil
    }
    return store(icon, key: key)
  }

  func prefetch(_ icons: [CommandIcon]) {
    for icon in icons {
      _ = store(icon, key: Self.key(for: icon) as NSString)
    }
  }

  private func scheduleLoad(_ icon: CommandIcon, key: String) {
    guard beginLoad(key) else {
      return
    }
    Task.detached(priority: .utility) {
      let cache = CommandIconCache.shared
      _ = cache.store(icon, key: key as NSString)
      cache.endLoad(key)
      await MainActor.run {
        CommandIconCache.onImagesLoaded?()
      }
    }
  }

  private func beginLoad(_ key: String) -> Bool {
    inflight.lock()
    let inserted = loading.insert(key).inserted
    inflight.unlock()
    return inserted
  }

  private func endLoad(_ key: String) {
    inflight.lock()
    loading.remove(key)
    inflight.unlock()
  }

  private func store(_ icon: CommandIcon, key: NSString) -> NSImage? {
    if let hit = images.object(forKey: key) {
      return hit
    }
    guard let image = load(icon), image.isValid else {
      misses.setObject(1, forKey: key)
      return nil
    }
    images.setObject(image, forKey: key)
    return image
  }

  private func load(_ icon: CommandIcon) -> NSImage? {
    switch icon {
    case let .fileIcon(path):
      guard FileManager.default.fileExists(atPath: path) else {
        return nil
      }
      return NSWorkspace.shared.icon(forFile: path)
    case let .imageFile(path):
      return NSImage(contentsOfFile: path)
    case let .application(bundleIdentifier):
      guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
        return nil
      }
      return NSWorkspace.shared.icon(forFile: url.path)
    case let .bundleResource(bundlePath, name):
      return Bundle(path: bundlePath)?.image(forResource: NSImage.Name(name))
    case let .symbol(name):
      return NSImage(systemSymbolName: name, accessibilityDescription: nil)
    }
  }

  private static func key(for icon: CommandIcon) -> String {
    switch icon {
    case let .fileIcon(path): "file:\(path)"
    case let .imageFile(path): "image:\(path)"
    case let .application(bundleIdentifier): "app:\(bundleIdentifier)"
    case let .bundleResource(bundlePath, name): "resource:\(bundlePath)#\(name)"
    case let .symbol(name): "symbol:\(name)"
    }
  }
}

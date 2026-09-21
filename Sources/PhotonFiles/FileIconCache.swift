import AppKit

/// Finder icons keyed by path. Results are prefetched on a background thread
/// right after ranking, so rows render with their icon on first draw.
public final class FileIconCache: @unchecked Sendable {
  public static let shared = FileIconCache()

  private let cache = NSCache<NSString, NSImage>()
  private let placeholder = NSImage(size: NSSize(width: 32, height: 32))

  init() {
    cache.countLimit = 600
  }

  public func icon(for file: FileResult) -> NSImage {
    icon(forPath: file.path)
  }

  public func icon(forPath path: String) -> NSImage {
    let key = path as NSString
    if let cached = cache.object(forKey: key) {
      return cached
    }
    if Thread.isMainThread {
      scheduleLoad(path)
      return placeholder
    }
    let image = NSWorkspace.shared.icon(forFile: path)
    cache.setObject(image, forKey: key)
    return image
  }

  public func prefetch(_ files: [FileResult]) {
    for file in files {
      let key = file.path as NSString
      if cache.object(forKey: key) != nil {
        continue
      }
      let image = NSWorkspace.shared.icon(forFile: file.path)
      cache.setObject(image, forKey: key)
    }
  }

  private func scheduleLoad(_ path: String) {
    Task.detached(priority: .utility) { [self] in
      let key = path as NSString
      if cache.object(forKey: key) != nil {
        return
      }
      let image = NSWorkspace.shared.icon(forFile: path)
      cache.setObject(image, forKey: key)
    }
  }
}

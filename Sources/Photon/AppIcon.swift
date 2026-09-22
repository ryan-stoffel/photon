import AppKit

/// The same Photon artwork Finder shows for `Photon.app`.
enum PhotonAppIcon {
  private static let bundleID = "com.ryanstoffel.photon"
  private static var cached: NSImage?

  static func install() {
    let image = make()
    cached = image
    NSApp.applicationIconImage = image
  }

  static var current: NSImage {
    if let cached {
      return cached
    }
    let image = make()
    cached = image
    return image
  }

  /// Finder icon for Photon's own bundle. Other apps keep the workspace icon.
  static func interfaceImage(forAppAt path: String) -> NSImage? {
    guard isPhoton(path), let bundled = bundledIcon(at: path) else {
      return nil
    }
    return IconBitmap.forInterface(bundled)
  }

  private static func make() -> NSImage {
    if let bundled = bundledIcon(at: Bundle.main.bundlePath) {
      return IconBitmap.forInterface(bundled)
    }
    return IconBitmap.forInterface(NSApp.applicationIconImage)
  }

  private static func isPhoton(_ path: String) -> Bool {
    Bundle(path: path)?.bundleIdentifier == bundleID
  }

  private static func bundledIcon(at path: String) -> NSImage? {
    let bundle = Bundle(path: path) ?? Bundle.main
    guard let named = bundle.object(forInfoDictionaryKey: "CFBundleIconFile") as? String, !named.isEmpty else {
      if let url = bundle.url(forResource: "Photon", withExtension: "icns") {
        return NSImage(contentsOf: url)
      }
      return nil
    }
    let base = (named as NSString).deletingPathExtension
    if let url = bundle.url(forResource: base, withExtension: "icns"),
       let image = NSImage(contentsOf: url) {
      return image
    }
    let file = named.hasSuffix(".icns") ? named : named + ".icns"
    guard let resources = bundle.resourceURL else {
      return nil
    }
    return NSImage(contentsOf: resources.appendingPathComponent(file))
  }
}

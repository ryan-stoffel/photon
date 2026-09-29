import Foundation

/// Release vs dev identity. Packaging sets the bundle id; the binary is the same.
enum PhotonProduct {
  static let releaseBundleID = "com.ryanstoffel.photon"
  static let devBundleID = "com.ryanstoffel.photon.dev"

  static var bundleIdentifier: String {
    Bundle.main.bundleIdentifier ?? releaseBundleID
  }

  static var isDev: Bool {
    bundleIdentifier == devBundleID
  }

  static var displayName: String {
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !name.isEmpty {
      return name
    }
    return isDev ? "Photon-Dev" : "Photon"
  }
}

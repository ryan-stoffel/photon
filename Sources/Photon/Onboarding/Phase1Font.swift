import AppKit
import CoreText
import SwiftUI

/// Bundled Sora (SIL Open Font License). Registered at launch.
enum Phase1Font {
  static let family = "Sora"
  static let postScriptName = "Sora-Regular"

  @MainActor
  static func registerAtLaunch() {
    for url in bundledFontURLs() {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
    if resolvedName() == nil {
      missingFont()
    }
  }

  static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    guard let name = resolvedName() else {
      missingFont()
      return Font.custom(family, size: size).weight(weight)
    }
    return Font.custom(name, size: size).weight(weight)
  }

  static func resolvedName() -> String? {
    for name in [family, postScriptName] where NSFont(name: name, size: Phase1Metrics.wordmarkSize) != nil {
      return name
    }
    return nil
  }

  private static func missingFont() {
    NSLog("Photon: Sora is not registered. Refusing a silent system-font fallback.")
    #if DEBUG
    assertionFailure("Sora is missing. Bundle Resources/Fonts/Sora-Variable.ttf and register it before drawing.")
    #endif
  }

  private static func bundledFontURLs() -> [URL] {
    let folder = Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true)
    let contents = folder.flatMap { url in
      try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    } ?? []
    return contents.filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
  }
}

import AppKit
import CoreText
import SwiftUI

/// Sora (SIL Open Font License) for onboarding text. Registered at launch.
enum OnboardingFont {
  static let family = "Sora"

  @MainActor
  static func registerAtLaunch() {
    for url in bundledFontURLs() {
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }

  static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
    let name = NSFont(name: family, size: size) == nil ? "Sora-Regular" : family
    return Font.custom(name, size: size).weight(weight)
  }

  private static func bundledFontURLs() -> [URL] {
    let folder = Bundle.main.resourceURL?.appendingPathComponent("Fonts", isDirectory: true)
    let contents = folder.flatMap { url in
      try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
    } ?? []
    return contents.filter { ["ttf", "otf"].contains($0.pathExtension.lowercased()) }
  }
}

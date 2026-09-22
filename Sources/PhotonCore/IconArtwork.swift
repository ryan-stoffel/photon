import Foundation

/// How much of an icon bitmap is artwork rather than empty padding.
public enum IconArtwork {
  /// Finder draws Photon's icon at about 0.84 of the square.
  /// Below this, the artwork is a speck inside a clear tile.
  public static let fullFraction = 0.62

  public static func needsCrop(contentFraction: Double) -> Bool {
    contentFraction > 0 && contentFraction < fullFraction
  }
}

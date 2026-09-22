import AppKit
import PhotonCore

/// One bitmap of the largest icon representation.
///
/// `Photon.icns` is a full icon, and Finder draws it that way. SwiftUI and
/// menu images keep every representation and paint the 32px one as a speck.
enum IconBitmap {
  struct Metrics {
    var representations: Int
    var fill: Double
  }

  static func forInterface(_ image: NSImage) -> NSImage {
    if image.representations.count <= 1, IconFractionCache.shared.value(for: image) != nil {
      return image
    }
    guard let cgImage = largestCGImage(in: image) else {
      return image
    }
    let fraction = contentFraction(of: cgImage)
    if image.representations.count <= 1, !IconArtwork.needsCrop(contentFraction: fraction) {
      IconFractionCache.shared.set(fraction, for: image)
      return image
    }
    let artwork = croppedArtwork(cgImage, fraction: fraction)
    let prepared = singleRepresentation(artwork)
    let displayed = contentFraction(of: artwork)
    IconFractionCache.shared.set(displayed, for: prepared)
    return prepared
  }

  static func metrics(_ image: NSImage) -> Metrics {
    let fill = IconFractionCache.shared.value(for: image) ?? contentFraction(of: image)
    return Metrics(representations: image.representations.count, fill: fill)
  }

  static func largestCGImage(in image: NSImage) -> CGImage? {
    let largest = image.representations.max { lhs, rhs in
      lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
    }
    if let largest, largest.pixelsWide > 0, largest.pixelsHigh > 0,
       let cgImage = largest.cgImage(forProposedRect: nil, context: nil, hints: nil)
    {
      return cgImage
    }
    var proposed = NSRect(origin: .zero, size: image.size)
    return image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
  }

  static func contentFraction(of image: NSImage) -> Double {
    if let stored = IconFractionCache.shared.value(for: image) {
      return stored
    }
    guard let cgImage = largestCGImage(in: image) else {
      return 0
    }
    let fraction = contentFraction(of: cgImage)
    IconFractionCache.shared.set(fraction, for: image)
    return fraction
  }

  private static func croppedArtwork(_ image: CGImage, fraction: Double) -> CGImage {
    guard IconArtwork.needsCrop(contentFraction: fraction),
          let bounds = opaqueBounds(of: image),
          let cropped = image.cropping(to: bounds)
    else {
      return image
    }
    return cropped
  }

  private static func singleRepresentation(_ image: CGImage) -> NSImage {
    let rep = NSBitmapImageRep(cgImage: image)
    let points = NSSize(width: 32, height: 32)
    rep.size = points
    let prepared = NSImage(size: points)
    prepared.addRepresentation(rep)
    return prepared
  }

  private static func contentFraction(of image: CGImage) -> Double {
    guard let bounds = opaqueBounds(of: image) else {
      return 0
    }
    let side = min(image.width, image.height)
    guard side > 0 else {
      return 0
    }
    let span = min(bounds.width, bounds.height)
    return Double(span) / Double(side)
  }

  private static func opaqueBounds(of image: CGImage) -> CGRect? {
    let width = image.width
    let height = image.height
    guard width > 0, height > 0 else {
      return nil
    }
    let bytesPerRow = width * 4
    var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
    return pixels.withUnsafeMutableBytes { buffer -> CGRect? in
      guard let base = buffer.baseAddress,
            let context = CGContext(
              data: base,
              width: width,
              height: height,
              bitsPerComponent: 8,
              bytesPerRow: bytesPerRow,
              space: CGColorSpaceCreateDeviceRGB(),
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
      else {
        return CGRect(x: 0, y: 0, width: width, height: height)
      }
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      return bounds(in: buffer, width: width, height: height, bytesPerRow: bytesPerRow)
    }
  }

  private static func bounds(
    in buffer: UnsafeMutableRawBufferPointer,
    width: Int,
    height: Int,
    bytesPerRow: Int
  ) -> CGRect? {
    let step = max(1, min(width, height) / 64)
    var minX = width
    var minY = height
    var maxX = 0
    var maxY = 0
    var found = false
    guard let base = buffer.assumingMemoryBound(to: UInt8.self).baseAddress else {
      return CGRect(x: 0, y: 0, width: width, height: height)
    }
    var y = 0
    while y < height {
      var x = 0
      let row = base.advanced(by: y * bytesPerRow)
      while x < width {
        if row[x * 4 + 3] > 20 {
          found = true
          minX = min(minX, x)
          minY = min(minY, y)
          maxX = max(maxX, x)
          maxY = max(maxY, y)
        }
        x += step
      }
      y += step
    }
    guard found else {
      return nil
    }
    let x0 = max(0, minX - step)
    let y0 = max(0, minY - step)
    let x1 = min(width - 1, maxX + step)
    let y1 = min(height - 1, maxY + step)
    return CGRect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
  }
}

private final class IconFractionCache: @unchecked Sendable {
  static let shared = IconFractionCache()

  private let lock = NSLock()
  private var values: [ObjectIdentifier: Double] = [:]

  func value(for image: NSImage) -> Double? {
    lock.lock()
    defer { lock.unlock() }
    return values[ObjectIdentifier(image)]
  }

  func set(_ fraction: Double, for image: NSImage) {
    lock.lock()
    values[ObjectIdentifier(image)] = fraction
    lock.unlock()
  }
}

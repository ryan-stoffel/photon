import AppKit
import CoreText

/// Menu-bar image. The release build keeps the template sun. The dev build draws the
/// same yellow "dev" tag used on `Photon-Dev.app` (see `Scripts/badge-dev-icon.swift`).
@MainActor
enum MenuBarStatusImage {
  static func make(devBadge: Bool, appearance: NSAppearance, points: CGFloat, scale: CGFloat) -> NSImage? {
    let description = PhotonProduct.displayName
    guard let symbol = NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: description) else {
      return nil
    }
    guard devBadge else {
      symbol.isTemplate = true
      return symbol
    }
    let resolvedScale = max(scale, 1)
    let pixels = max(18, Int((points * resolvedScale).rounded()))
    guard let cgImage = badged(symbol: symbol, appearance: appearance, pixels: pixels, scale: resolvedScale) else {
      symbol.isTemplate = true
      return symbol
    }
    let image = NSImage(cgImage: cgImage, size: NSSize(width: points, height: points))
    image.isTemplate = false
    image.accessibilityDescription = description
    return image
  }

  private static func badged(
    symbol: NSImage,
    appearance: NSAppearance,
    pixels: Int,
    scale: CGFloat
  ) -> CGImage? {
    let pointSize = CGFloat(pixels) / scale * 0.62
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
    guard let configured = symbol.withSymbolConfiguration(config) else {
      return nil
    }
    var proposed = NSRect(origin: .zero, size: configured.size)
    guard let symbolImage = configured.cgImage(forProposedRect: &proposed, context: nil, hints: nil) else {
      return nil
    }
    guard let context = CGContext(
      data: nil,
      width: pixels,
      height: pixels,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return nil
    }
    context.interpolationQuality = .high
    let canvas = CGSize(width: pixels, height: pixels)
    draw(symbolImage, color: symbolColor(for: appearance), in: context, canvas: canvas)
    DevMenuTag.draw(in: context, canvas: canvas)
    return context.makeImage()
  }

  private static func draw(_ symbol: CGImage, color: NSColor, in context: CGContext, canvas: CGSize) {
    let width = CGFloat(symbol.width)
    let height = CGFloat(symbol.height)
    let dest = CGRect(
      x: (canvas.width - width) / 2,
      y: (canvas.height - height) / 2,
      width: width,
      height: height
    )
    context.saveGState()
    context.clip(to: dest, mask: symbol)
    context.setFillColor(color.cgColor)
    context.fill(dest)
    context.restoreGState()
  }

  private static func symbolColor(for appearance: NSAppearance) -> NSColor {
    let match = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
    if match == .darkAqua || match == .vibrantDark {
      return .white
    }
    return .black
  }
}

@MainActor
private enum DevMenuTag {
  static let yellow = CGColor(srgbRed: 1, green: 0.82, blue: 0, alpha: 1)

  static func draw(in context: CGContext, canvas: CGSize) {
    let side = min(canvas.width, canvas.height)
    let height = max(4, (side * 0.40).rounded())
    let width = max(height * 1.6, (height * 2.15).rounded())
    let inset = (side * 0.04).rounded()
    let tag = CGRect(
      x: canvas.width - inset - width,
      y: canvas.height - inset - height,
      width: width,
      height: height
    )
    let radius = height * 0.28
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: -max(0.5, side * 0.008)),
      blur: max(0.5, side * 0.01),
      color: CGColor(gray: 0, alpha: 0.45)
    )
    context.setFillColor(yellow)
    context.addPath(CGPath(roundedRect: tag, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
    context.restoreGState()

    let font = NSFont.systemFont(ofSize: height * 0.58, weight: .black)
    let text = NSAttributedString(string: "dev", attributes: [
      .font: font,
      .foregroundColor: NSColor.black,
    ])
    let line = CTLineCreateWithAttributedString(text)
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    let textWidth = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
    let textHeight = ascent + descent
    context.textPosition = CGPoint(
      x: tag.midX - textWidth / 2,
      y: tag.midY - textHeight / 2 + descent
    )
    CTLineDraw(line, context)
  }
}

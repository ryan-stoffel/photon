import AppKit
import CoreText

/// Menu-bar image. Release builds draw an outlined Photon mark and mark it as a
/// template so the menu bar tints it. Dev builds draw the same mark with the yellow
/// "dev" tag used on `Photon-Dev.app` (see `Scripts/badge-dev-icon.swift`).
/// The Dock and Finder icon stays `Resources/Photon.icns`.
@MainActor
enum MenuBarStatusImage {
  static func make(devBadge: Bool, appearance: NSAppearance, points: CGFloat, scale: CGFloat) -> NSImage? {
    let side = points > 1 ? points : 18
    let description = PhotonProduct.displayName
    let image = NSImage(size: NSSize(width: side, height: side))
    let color = devBadge ? symbolColor(for: appearance) : .black
    var added = false
    for pixels in pixelSizes(points: side, scale: scale) {
      guard let cgImage = render(pixels: pixels, color: color.cgColor, devBadge: devBadge) else {
        continue
      }
      let rep = NSBitmapImageRep(cgImage: cgImage)
      rep.size = NSSize(width: side, height: side)
      image.addRepresentation(rep)
      added = true
    }
    guard added else {
      return nil
    }
    image.isTemplate = !devBadge
    image.accessibilityDescription = description
    return image
  }

  /// Device-pixel sizes for the status item. Includes the screen scale plus the
  /// usual 1x, 2x, and 3x sizes so the stroke stays 1:1 on the menu bar.
  private static func pixelSizes(points: CGFloat, scale: CGFloat) -> [Int] {
    let factors: [CGFloat] = [1, 2, 3, max(scale, 1)]
    var sizes: [Int] = []
    for factor in factors {
      let pixels = max(16, Int((points * factor).rounded()))
      if !sizes.contains(pixels) {
        sizes.append(pixels)
      }
    }
    return sizes
  }

  private static func render(pixels: Int, color: CGColor, devBadge: Bool) -> CGImage? {
    guard let context = bitmapContext(pixels: pixels) else {
      return nil
    }
    let canvas = CGSize(width: pixels, height: pixels)
    drawMark(in: context, canvas: canvas, color: color, devBadge: devBadge)
    if devBadge {
      DevMenuTag.draw(in: context, canvas: canvas)
    }
    return context.makeImage()
  }

  private static func bitmapContext(pixels: Int) -> CGContext? {
    let context = CGContext(
      data: nil,
      width: pixels,
      height: pixels,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
    context?.interpolationQuality = .none
    context?.setAllowsAntialiasing(true)
    context?.setShouldAntialias(true)
    return context
  }

  /// Rounded tile plus the icon's horizontal light streak, both stroked.
  /// The streak is larger than the soft glow in `Photon.icns` so the outline
  /// still reads at menu-bar size. `(u, v)` is top-left of the tile.
  private static func drawMark(in context: CGContext, canvas: CGSize, color: CGColor, devBadge: Bool) {
    let side = min(canvas.width, canvas.height)
    let fill = devBadge ? PhotonMark.badgeFill : PhotonMark.releaseFill
    let glyph = side * fill
    let stroke = max(1, (glyph * PhotonMark.strokeFraction).rounded())
    let origin = ((side - glyph) / 2).rounded()
    let rect = CGRect(
      x: origin + stroke / 2,
      y: origin + stroke / 2,
      width: max(1, glyph - stroke),
      height: max(1, glyph - stroke)
    )
    context.setStrokeColor(color)
    context.setLineWidth(stroke)
    context.setLineJoin(.round)
    context.setLineCap(.round)

    let corner = rect.width * PhotonMark.cornerFraction
    context.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    context.strokePath()

    let tail = point(in: rect, u: PhotonMark.tailU, v: PhotonMark.tailV)
    let head = point(in: rect, u: PhotonMark.headU, v: PhotonMark.headV)
    let radius = min(rect.width, rect.height) * PhotonMark.headRadiusFraction
    let streak = CGMutablePath()
    addComet(to: streak, tail: tail, center: head, radius: radius)
    context.addPath(streak)
    context.strokePath()
  }

  private static func point(in rect: CGRect, u: CGFloat, v: CGFloat) -> CGPoint {
    CGPoint(x: rect.minX + rect.width * u, y: rect.maxY - rect.height * v)
  }

  /// Closed stroke: tail on the left, round head on the right. The arc is the
  /// long way around so it faces away from the tail.
  private static func addComet(to path: CGMutablePath, tail: CGPoint, center: CGPoint, radius: CGFloat) {
    let dx = tail.x - center.x
    let dy = tail.y - center.y
    let distance = CGFloat(hypot(Double(dx), Double(dy)))
    guard distance > radius + 0.5, radius > 0 else {
      path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
      return
    }
    let base = CGFloat(atan2(Double(dy), Double(dx)))
    let phi = CGFloat(acos(Double(min(1, radius / distance))))
    path.move(to: tail)
    path.addArc(
      center: center,
      radius: radius,
      startAngle: base + phi,
      endAngle: base - phi,
      clockwise: false
    )
    path.closeSubpath()
  }

  private static func symbolColor(for appearance: NSAppearance) -> NSColor {
    let match = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
    if match == .darkAqua || match == .vibrantDark {
      return .white
    }
    return .black
  }
}

private enum PhotonMark {
  static let releaseFill: CGFloat = 0.86
  static let badgeFill: CGFloat = 0.70
  static let strokeFraction: CGFloat = 0.08
  static let cornerFraction: CGFloat = 0.264
  static let tailU: CGFloat = 0.24
  static let tailV: CGFloat = 0.50
  static let headU: CGFloat = 0.62
  static let headV: CGFloat = 0.48
  static let headRadiusFraction: CGFloat = 0.115
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

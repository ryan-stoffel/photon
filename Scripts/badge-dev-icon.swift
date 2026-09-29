import AppKit
import CoreText
import Foundation
import UniformTypeIdentifiers

// Draws a yellow "dev" tag on the top-right of Photon.icns and writes a new icns.
// The source file is not modified. Invoked by `Scripts/package_app.sh --dev`.

enum DevIconBadge {
  static let yellow = CGColor(srgbRed: 1, green: 0.82, blue: 0, alpha: 1)

  static func render(source: CGImage, side: Int) -> CGImage? {
    guard let context = CGContext(
      data: nil,
      width: side,
      height: side,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return nil
    }
    context.interpolationQuality = .high
    context.draw(source, in: CGRect(x: 0, y: 0, width: side, height: side))
    drawTag(in: context, side: CGFloat(side))
    return context.makeImage()
  }

  private static func drawTag(in context: CGContext, side: CGFloat) {
    let height = max(4, (side * 0.18).rounded())
    let width = max(height * 1.6, (height * 2.15).rounded())
    let inset = (side * 0.16).rounded()
    let tag = CGRect(x: side - inset - width, y: side - inset - height, width: width, height: height)
    let radius = height * 0.28
    context.saveGState()
    context.setShadow(
      offset: CGSize(width: 0, height: -max(0.5, side * 0.008)),
      blur: max(0.5, side * 0.01),
      color: CGColor(gray: 0, alpha: 0.4)
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

func loadSource(at url: URL) -> CGImage? {
  guard let image = NSImage(contentsOf: url) else {
    return nil
  }
  let rep = image.representations.max { lhs, rhs in
    lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
  }
  guard let rep else {
    return nil
  }
  var rect = NSRect(x: 0, y: 0, width: rep.pixelsWide, height: rep.pixelsHigh)
  return rep.cgImage(forProposedRect: &rect, context: nil, hints: nil)
}

func writePNG(_ image: CGImage, to url: URL) -> Bool {
  guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    return false
  }
  CGImageDestinationAddImage(dest, image, nil)
  return CGImageDestinationFinalize(dest)
}

let iconsetFiles: [(Int, [String])] = [
  (16, ["icon_16x16.png"]),
  (32, ["icon_16x16@2x.png", "icon_32x32.png"]),
  (64, ["icon_32x32@2x.png"]),
  (128, ["icon_128x128.png"]),
  (256, ["icon_128x128@2x.png", "icon_256x256.png"]),
  (512, ["icon_256x256@2x.png", "icon_512x512.png"]),
  (1024, ["icon_512x512@2x.png"]),
]

let arguments = CommandLine.arguments
guard arguments.count == 3 else {
  fputs("usage: badge-dev-icon.swift input.icns output.icns\n", stderr)
  exit(2)
}

let inputURL = URL(fileURLWithPath: arguments[1])
let outputURL = URL(fileURLWithPath: arguments[2])
guard let source = loadSource(at: inputURL) else {
  fputs("Could not read \(inputURL.path)\n", stderr)
  exit(1)
}

let iconset = FileManager.default.temporaryDirectory
  .appendingPathComponent("Photon-Dev-\(ProcessInfo.processInfo.processIdentifier).iconset")
defer { try? FileManager.default.removeItem(at: iconset) }

do {
  try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
  for (side, names) in iconsetFiles {
    guard let image = DevIconBadge.render(source: source, side: side) else {
      fputs("Could not render \(side)px icon\n", stderr)
      exit(1)
    }
    for name in names {
      let url = iconset.appendingPathComponent(name)
      guard writePNG(image, to: url) else {
        fputs("Could not write \(url.path)\n", stderr)
        exit(1)
      }
    }
  }
} catch {
  fputs("Could not prepare iconset: \(error)\n", stderr)
  exit(1)
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
do {
  try iconutil.run()
  iconutil.waitUntilExit()
} catch {
  fputs("iconutil failed: \(error)\n", stderr)
  exit(1)
}

guard iconutil.terminationStatus == 0 else {
  fputs("iconutil exited \(iconutil.terminationStatus)\n", stderr)
  exit(iconutil.terminationStatus)
}

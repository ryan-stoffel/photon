import AppKit

/// Panel background: Liquid Glass when `NSGlassEffectView` exists, otherwise vibrancy.
enum PhotonPanelChrome {
  static var glassEffectAvailable: Bool {
    NSClassFromString("NSGlassEffectView") != nil
  }

  static func embed(
    _ content: NSView,
    frame: NSRect,
    cornerRadius: CGFloat,
    material: NSVisualEffectView.Material = .popover
  ) -> NSView {
    content.translatesAutoresizingMaskIntoConstraints = true
    content.autoresizingMask = [.width, .height]
    if let glass = makeGlass(frame: frame, cornerRadius: cornerRadius) {
      content.frame = glass.bounds
      if glass.responds(to: NSSelectorFromString("setContentView:")) {
        glass.setValue(content, forKey: "contentView")
      }
      if content.superview == nil {
        glass.addSubview(content)
      }
      return glass
    }
    let vibrant = makeVibrant(frame: frame, cornerRadius: cornerRadius, material: material)
    content.frame = vibrant.bounds
    vibrant.addSubview(content)
    return vibrant
  }

  static func makeVibrant(
    frame: NSRect,
    cornerRadius: CGFloat,
    material: NSVisualEffectView.Material
  ) -> NSVisualEffectView {
    let background = NSVisualEffectView(frame: frame)
    apply(to: background, material: material, cornerRadius: cornerRadius)
    return background
  }

  static func apply(
    to effectView: NSVisualEffectView,
    material: NSVisualEffectView.Material,
    cornerRadius: CGFloat? = nil
  ) {
    effectView.material = material
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    effectView.wantsLayer = true
    if let cornerRadius {
      effectView.layer?.cornerRadius = cornerRadius
      effectView.layer?.cornerCurve = .continuous
      effectView.layer?.masksToBounds = true
    }
    effectView.autoresizingMask = [.width, .height]
  }

  private static func makeGlass(frame: NSRect, cornerRadius: CGFloat) -> NSView? {
    guard let glassClass = NSClassFromString("NSGlassEffectView") as? NSView.Type else {
      return nil
    }
    let glass = glassClass.init(frame: frame)
    glass.autoresizingMask = [.width, .height]
    if glass.responds(to: NSSelectorFromString("setCornerRadius:")) {
      glass.setValue(cornerRadius, forKey: "cornerRadius")
    }
    if glass.responds(to: NSSelectorFromString("setStyle:")) {
      glass.setValue(0, forKey: "style")
    }
    glass.wantsLayer = true
    glass.layer?.cornerRadius = cornerRadius
    glass.layer?.cornerCurve = .continuous
    glass.layer?.masksToBounds = true
    return glass
  }
}

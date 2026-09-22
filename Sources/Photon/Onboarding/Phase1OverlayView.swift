import SwiftUI

struct Phase1Model: Sendable {
  var started = Date()
  var settled: Bool
  var reduceMotion: Bool

  func frame(at date: Date) -> Phase1Frame {
    Phase1Clock.frame(
      elapsed: date.timeIntervalSince(started),
      settled: settled,
      reduceMotion: reduceMotion
    )
  }

  func isResting(at date: Date = Date()) -> Bool {
    frame(at: date).isResting
  }
}

struct Phase1OverlayView: View {
  let model: Phase1Model

  var body: some View {
    TimelineView(.animation) { timeline in
      Phase1Scene(
        frame: model.frame(at: timeline.date),
        time: timeline.date.timeIntervalSinceReferenceDate
      )
    }
    .ignoresSafeArea()
  }
}

private struct Phase1Scene: View {
  var frame: Phase1Frame
  var time: TimeInterval

  var body: some View {
    ZStack {
      Phase1Metrics.dimColor.opacity(Phase1Metrics.dimOpacity * frame.background)
      Phase1Haze(opacity: frame.background)
      Phase1Sky(opacity: frame.background, time: time)
      if frame.beamVisible {
        Phase1Beam(progress: frame.beamProgress, collapse: frame.beamCollapse)
      }
      if frame.flashOpacity > 0 {
        Phase1Flash(opacity: frame.flashOpacity, progress: frame.flashProgress)
      }
      Phase1Mark(opacity: frame.markOpacity, scale: frame.markScale)
    }
    .ignoresSafeArea()
  }
}

private struct Phase1Haze: View {
  var opacity: CGFloat

  var body: some View {
    LinearGradient(
      stops: [
        .init(color: Phase1Metrics.hazeColor.opacity(0), location: 0),
        .init(color: Phase1Metrics.hazeColor.opacity(0), location: Phase1Metrics.hazeClearStop),
        .init(
          color: Phase1Metrics.hazeColor.opacity(Phase1Metrics.hazePeakOpacity * opacity),
          location: 1
        ),
      ],
      startPoint: .top,
      endPoint: .bottom
    )
    .allowsHitTesting(false)
  }
}

private struct Phase1Sky: View {
  var opacity: CGFloat
  var time: TimeInterval

  var body: some View {
    Canvas { context, size in
      for star in Phase1Stars.field {
        let alpha = Phase1Stars.brightness(star, at: time) * opacity
        let origin = Phase1Stars.origin(star, at: time, in: size)
        let rect = CGRect(
          x: origin.x - star.radius,
          y: origin.y - star.radius,
          width: star.radius * 2,
          height: star.radius * 2
        )
        context.fill(
          Path(ellipseIn: rect),
          with: .color(Phase1Metrics.starColor.opacity(alpha))
        )
      }
    }
    .allowsHitTesting(false)
  }
}

private struct Phase1Beam: View {
  var progress: CGFloat
  var collapse: CGFloat

  var body: some View {
    Canvas { context, size in
      var context = context
      draw(progress: progress, collapse: collapse, in: &context, size: size)
    }
    .allowsHitTesting(false)
  }

  private func draw(
    progress: CGFloat,
    collapse: CGFloat,
    in context: inout GraphicsContext,
    size: CGSize
  ) {
    let tipX = progress * size.width * Phase1Metrics.centerFraction
    let midY = size.height * Phase1Metrics.centerFraction
    let span = Phase1Metrics.beamTailLength * (1 - collapse)
    let startX = tipX - span
    guard span > Phase1Metrics.beamMinSpan else {
      return
    }
    let brightness = (
      Phase1Metrics.beamMinBrightness + (1 - Phase1Metrics.beamMinBrightness) * progress
    ) * (1 - collapse)
    let bloom = Phase1Metrics.beamBloomMin + (Phase1Metrics.beamBloomMax - Phase1Metrics.beamBloomMin) * progress
    let geometry = BeamGeometry(startX: startX, tipX: tipX, midY: midY, span: span)
    drawRibbon(
      context,
      geometry: geometry,
      thickness: Phase1Metrics.beamGlowThickness * bloom,
      blur: Phase1Metrics.beamGlowBlur,
      color: Phase1Metrics.beamGlowColor.opacity(brightness * Phase1Metrics.beamGlowOpacity)
    )
    drawRibbon(
      context,
      geometry: geometry,
      thickness: Phase1Metrics.beamInnerThickness,
      blur: Phase1Metrics.beamInnerBlur,
      color: Phase1Metrics.beamCoreColor.opacity(brightness * Phase1Metrics.beamInnerOpacity)
    )
    drawCore(context, geometry: geometry, brightness: brightness)
    drawHead(context, geometry: geometry, brightness: brightness, bloom: bloom, collapse: collapse)
  }

  private func drawRibbon(
    _ context: GraphicsContext,
    geometry: BeamGeometry,
    thickness: CGFloat,
    blur: CGFloat,
    color: Color
  ) {
    let rect = CGRect(
      x: geometry.startX,
      y: geometry.midY - thickness / 2,
      width: geometry.span,
      height: thickness
    )
    var layer = context
    layer.addFilter(.blur(radius: blur))
    layer.fill(
      Path(roundedRect: rect, cornerRadius: thickness / 2),
      with: .linearGradient(
        Gradient(colors: [color.opacity(0), color]),
        startPoint: CGPoint(x: geometry.startX, y: geometry.midY),
        endPoint: CGPoint(x: geometry.tipX, y: geometry.midY)
      )
    )
  }

  private func drawCore(_ context: GraphicsContext, geometry: BeamGeometry, brightness: CGFloat) {
    let rect = CGRect(
      x: geometry.startX,
      y: geometry.midY - Phase1Metrics.beamThickness / 2,
      width: geometry.span,
      height: Phase1Metrics.beamThickness
    )
    context.fill(
      Path(roundedRect: rect, cornerRadius: Phase1Metrics.beamThickness / 2),
      with: .linearGradient(
        Gradient(colors: [
          Phase1Metrics.beamCoreColor.opacity(0),
          Phase1Metrics.beamCoreColor.opacity(brightness),
        ]),
        startPoint: CGPoint(x: geometry.startX, y: geometry.midY),
        endPoint: CGPoint(x: geometry.tipX, y: geometry.midY)
      )
    )
  }

  private func drawHead(
    _ context: GraphicsContext,
    geometry: BeamGeometry,
    brightness: CGFloat,
    bloom: CGFloat,
    collapse: CGFloat
  ) {
    let diameter = Phase1Metrics.beamHeadDiameter * bloom * (1 - min(0.85, collapse))
    let rect = CGRect(
      x: geometry.tipX - diameter / 2,
      y: geometry.midY - diameter / 2,
      width: diameter,
      height: diameter
    )
    var layer = context
    layer.addFilter(.blur(radius: Phase1Metrics.beamHeadBlur))
    layer.fill(
      Path(ellipseIn: rect),
      with: .color(Phase1Metrics.beamCoreColor.opacity(brightness * Phase1Metrics.beamHeadOpacity))
    )
  }
}

private struct BeamGeometry {
  var startX: CGFloat
  var tipX: CGFloat
  var midY: CGFloat
  var span: CGFloat
}

private struct Phase1Flash: View {
  var opacity: CGFloat
  var progress: CGFloat

  var body: some View {
    let scale = Phase1Metrics.flashScaleStart
      + (Phase1Metrics.flashScaleEnd - Phase1Metrics.flashScaleStart) * progress
    Circle()
      .fill(Phase1Metrics.flashColor)
      .frame(width: Phase1Metrics.flashDiameter, height: Phase1Metrics.flashDiameter)
      .scaleEffect(scale)
      .blur(radius: Phase1Metrics.flashBlur)
      .opacity(opacity)
      .allowsHitTesting(false)
  }
}

private struct Phase1Mark: View {
  var opacity: CGFloat
  var scale: CGFloat

  var body: some View {
    VStack(spacing: Phase1Metrics.wordmarkGap) {
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: Phase1Metrics.iconSize, height: Phase1Metrics.iconSize)
        .scaleEffect(scale)
      Text("Photon")
        .font(Phase1Font.font(size: Phase1Metrics.wordmarkSize, weight: .medium))
        .foregroundStyle(Phase1Metrics.wordmarkColor)
        .tracking(Phase1Metrics.wordmarkTracking)
    }
    .offset(y: -(Phase1Metrics.wordmarkGap + Phase1Metrics.wordmarkLineHeight) / 2)
    .opacity(opacity)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Phase1Metrics.restingStep)
  }
}

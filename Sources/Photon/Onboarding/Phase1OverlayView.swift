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
      var layer = context
      layer.blendMode = .plusLighter
      let geometry = BeamGeometry.make(progress: progress, collapse: collapse, size: size)
      guard geometry.span > Phase1Metrics.beamMinSpan else {
        return
      }
      drawTail(in: &layer, geometry: geometry)
      drawHead(in: &layer, geometry: geometry)
    }
    .blendMode(.plusLighter)
    .allowsHitTesting(false)
  }

  private func drawTail(in context: inout GraphicsContext, geometry: BeamGeometry) {
    let count = max(1, Int((geometry.span / Phase1Metrics.beamSampleSpacing).rounded(.up)))
    for index in 0 ... count {
      drawTailSample(in: &context, geometry: geometry, along: CGFloat(index) / CGFloat(count))
    }
  }

  private func drawTailSample(
    in context: inout GraphicsContext,
    geometry: BeamGeometry,
    along: CGFloat
  ) {
    let fade = smooth(along)
    guard fade > 0.02 else {
      return
    }
    let presence = fade * fade
    let radius = Phase1Metrics.beamHairlineRadius * (0.2 + 0.8 * fade)
    let alpha = geometry.brightness * Phase1Metrics.beamTailAlpha * presence
    let x = geometry.startX + geometry.span * along
    let rect = CGRect(x: x - radius, y: geometry.midY - radius, width: radius * 2, height: radius * 2)
    context.fill(
      Path(ellipseIn: rect),
      with: .radialGradient(
        Gradient(stops: tailStops(along: along, alpha: alpha)),
        center: CGPoint(x: x, y: geometry.midY),
        startRadius: 0,
        endRadius: radius
      )
    )
  }

  private func tailStops(along: CGFloat, alpha: CGFloat) -> [Gradient.Stop] {
    let color = tailColor(along: along, alpha: alpha)
    return [
      .init(color: color, location: 0),
      .init(color: color.opacity(0.35), location: 0.42),
      .init(color: color.opacity(0), location: 1),
    ]
  }

  private func tailColor(along: CGFloat, alpha: CGFloat) -> Color {
    let whiteMix = along * along
    let red = Phase1Metrics.beamTailRed + (Phase1Metrics.beamCoreRed - Phase1Metrics.beamTailRed) * whiteMix
    let green = Phase1Metrics.beamTailGreen + (Phase1Metrics.beamCoreGreen - Phase1Metrics.beamTailGreen) * whiteMix
    let blue = Phase1Metrics.beamTailBlue + (Phase1Metrics.beamCoreBlue - Phase1Metrics.beamTailBlue) * whiteMix
    return Color(red: red, green: green, blue: blue, opacity: alpha)
  }

  private func drawHead(in context: inout GraphicsContext, geometry: BeamGeometry) {
    let radius = Phase1Metrics.beamBloomRadius * geometry.bloom * (1 - geometry.collapse)
    guard radius > 0.5 else {
      return
    }
    let rect = CGRect(
      x: geometry.tipX - radius,
      y: geometry.midY - radius,
      width: radius * 2,
      height: radius * 2
    )
    context.fill(
      Path(ellipseIn: rect),
      with: .radialGradient(
        Gradient(stops: headStops(brightness: geometry.brightness)),
        center: CGPoint(x: geometry.tipX, y: geometry.midY),
        startRadius: 0,
        endRadius: radius
      )
    )
  }

  private func headStops(brightness: CGFloat) -> [Gradient.Stop] {
    let white = Phase1Metrics.beamCoreColor.opacity(brightness)
    let cyan = Color(
      red: Phase1Metrics.beamBloomRed,
      green: Phase1Metrics.beamBloomGreen,
      blue: Phase1Metrics.beamBloomBlue,
      opacity: brightness * Phase1Metrics.beamBloomOpacity
    )
    let clear = Color(
      red: Phase1Metrics.beamBloomRed,
      green: Phase1Metrics.beamBloomGreen,
      blue: Phase1Metrics.beamBloomBlue,
      opacity: 0
    )
    let core = Phase1Metrics.beamHeadCoreDiameter / 2 / Phase1Metrics.beamBloomRadius
    return [
      .init(color: white, location: 0),
      .init(color: white, location: core),
      .init(color: cyan, location: min(1, core + 0.12)),
      .init(color: cyan.opacity(0.42), location: 0.55),
      .init(color: clear, location: 1),
    ]
  }

  private func smooth(_ t: CGFloat) -> CGFloat {
    let x = min(1, max(0, t))
    return x * x * (3 - 2 * x)
  }
}

private struct BeamGeometry {
  var startX: CGFloat
  var tipX: CGFloat
  var midY: CGFloat
  var span: CGFloat
  var brightness: CGFloat
  var bloom: CGFloat
  var collapse: CGFloat

  static func make(progress: CGFloat, collapse: CGFloat, size: CGSize) -> BeamGeometry {
    let tipX = progress * size.width * Phase1Metrics.centerFraction
    let span = Phase1Metrics.beamTailLength * (1 - collapse)
    let gained = (1 - Phase1Metrics.beamMinBrightness) * progress
    let brightness = (Phase1Metrics.beamMinBrightness + gained) * (1 - collapse)
    let bloomSpan = Phase1Metrics.beamBloomMax - Phase1Metrics.beamBloomMin
    return BeamGeometry(
      startX: tipX - span,
      tipX: tipX,
      midY: size.height * Phase1Metrics.centerFraction,
      span: span,
      brightness: brightness,
      bloom: Phase1Metrics.beamBloomMin + bloomSpan * progress,
      collapse: collapse
    )
  }
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

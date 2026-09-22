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
        Phase1Beam(progress: frame.beamProgress)
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
    ZStack {
      haze(.bottomLeading)
      haze(.bottomTrailing)
    }
    .allowsHitTesting(false)
  }

  private func haze(_ center: UnitPoint) -> some View {
    RadialGradient(
      colors: [
        Phase1Metrics.hazeColor.opacity(Phase1Metrics.hazePeakOpacity * opacity),
        Phase1Metrics.hazeColor.opacity(0),
      ],
      center: center,
      startRadius: Phase1Metrics.hazeStartRadius,
      endRadius: Phase1Metrics.hazeEndRadius
    )
  }
}

private struct Phase1Sky: View {
  var opacity: CGFloat
  var time: TimeInterval

  var body: some View {
    Canvas { context, size in
      for star in Phase1Stars.field {
        let alpha = Phase1Stars.brightness(star, at: time) * opacity
        let origin = CGPoint(x: star.x * size.width, y: star.y * size.height)
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

  var body: some View {
    Canvas { context, size in
      var context = context
      draw(progress: progress, in: &context, size: size)
    }
    .allowsHitTesting(false)
  }

  private func draw(progress: CGFloat, in context: inout GraphicsContext, size: CGSize) {
    let tipX = progress * size.width * Phase1Metrics.centerFraction
    let midY = size.height * Phase1Metrics.centerFraction
    let startX = max(0, tipX - Phase1Metrics.beamTailLength)
    let width = tipX - startX
    guard width > Phase1Metrics.beamMinSpan else {
      return
    }
    let brightness = Phase1Metrics.beamMinBrightness
      + (1 - Phase1Metrics.beamMinBrightness) * progress
    let glow = Phase1Metrics.beamGlowMin
      + (Phase1Metrics.beamGlowMax - Phase1Metrics.beamGlowMin) * progress
    fillGlow(
      context,
      rect: CGRect(
        x: startX,
        y: midY - Phase1Metrics.beamSoftGlowThickness / 2,
        width: width,
        height: Phase1Metrics.beamSoftGlowThickness
      ),
      radius: glow * Phase1Metrics.beamSoftGlowScale,
      color: Phase1Metrics.beamGlowColor.opacity(brightness * Phase1Metrics.beamSoftGlowOpacity)
    )
    fillGlow(
      context,
      rect: CGRect(
        x: startX,
        y: midY - Phase1Metrics.beamGlowThickness / 2,
        width: width,
        height: Phase1Metrics.beamGlowThickness
      ),
      radius: glow,
      color: Phase1Metrics.beamGlowColor.opacity(brightness * Phase1Metrics.beamGlowOpacity)
    )
    let core = CGRect(
      x: startX,
      y: midY - Phase1Metrics.beamThickness / 2,
      width: width,
      height: Phase1Metrics.beamThickness
    )
    context.fill(
      Path(roundedRect: core, cornerRadius: Phase1Metrics.beamThickness / 2),
      with: .linearGradient(
        Gradient(colors: [
          Phase1Metrics.beamCoreColor.opacity(0),
          Phase1Metrics.beamCoreColor.opacity(brightness),
        ]),
        startPoint: CGPoint(x: startX, y: midY),
        endPoint: CGPoint(x: tipX, y: midY)
      )
    )
  }

  private func fillGlow(
    _ context: GraphicsContext,
    rect: CGRect,
    radius: CGFloat,
    color: Color
  ) {
    var layer = context
    layer.addFilter(.blur(radius: radius))
    layer.fill(
      Path(roundedRect: rect, cornerRadius: rect.height / 2),
      with: .color(color)
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

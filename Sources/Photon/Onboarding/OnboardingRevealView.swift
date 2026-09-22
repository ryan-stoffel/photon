import SwiftUI

struct OnboardingRevealView: View {
  @ObservedObject var model: OnboardingController
  var reduceMotion: Bool

  var body: some View {
    ZStack {
      if model.instant {
        OnboardingMark(scale: 1, glow: 0.34)
      } else {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
          let time = context.date.timeIntervalSince(model.revealStarted)
          let clock = OnboardingRevealClock(time: time, reduceMotion: reduceMotion)
          ZStack {
            if clock.beamVisible || clock.flash > 0 {
              OnboardingBeamCanvas(clock: clock)
            }
            OnboardingMark(scale: clock.markScale, glow: clock.glow)
              .opacity(clock.markOpacity)
          }
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

/// Icon and wordmark. The icon keeps a faint blue glow that breathes.
struct OnboardingMark: View {
  var scale: CGFloat
  var glow: Double

  var body: some View {
    VStack(spacing: 22) {
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 104, height: 104)
        .shadow(color: OnboardingColor.beam.opacity(glow), radius: 28)
        .shadow(color: OnboardingColor.beam.opacity(glow * 0.5), radius: 64)
      Text("Photon")
        .font(OnboardingFont.font(size: 40, weight: .medium))
        .tracking(0.4)
        .foregroundStyle(.white)
    }
    .scaleEffect(scale)
  }
}

/// Pure timing curves for one moment of the reveal.
struct OnboardingRevealClock {
  var time: TimeInterval
  var reduceMotion: Bool

  var beamVisible: Bool {
    !reduceMotion
      && time >= OnboardingTiming.revealBlack
      && time < OnboardingTiming.beamEnd + OnboardingTiming.beamCollapse
  }

  /// 0 at the left edge, 1 at center, ease-in-out.
  var beamProgress: CGFloat {
    let span = (time - OnboardingTiming.revealBlack) / OnboardingTiming.beam
    return CGFloat(OnboardingTiming.easeInOut(span))
  }

  /// 0 while the beam travels, 1 once it has pinched to a point.
  var collapse: CGFloat {
    guard time >= OnboardingTiming.beamEnd else {
      return 0
    }
    return CGFloat(OnboardingTiming.clamp((time - OnboardingTiming.beamEnd) / OnboardingTiming.beamCollapse))
  }

  /// Rises to 1 over the peak, then decays to 0.
  var flash: Double {
    guard !reduceMotion, time >= OnboardingTiming.flashStart, time < OnboardingTiming.holdStart else {
      return 0
    }
    if time < OnboardingTiming.decayStart {
      return OnboardingTiming.easeOut((time - OnboardingTiming.flashStart) / OnboardingTiming.flashPeak)
    }
    return 1 - OnboardingTiming.easeInOut((time - OnboardingTiming.decayStart) / OnboardingTiming.flashDecay)
  }

  /// How far the bloom has spread from the center point.
  var flashSpread: Double {
    let life = OnboardingTiming.flashPeak + OnboardingTiming.flashDecay
    return OnboardingTiming.easeOut((time - OnboardingTiming.flashStart) / life)
  }

  var markOpacity: Double {
    if reduceMotion {
      return OnboardingTiming.clamp(time / OnboardingTiming.reducedCrossfade)
    }
    guard time > OnboardingTiming.decayStart else {
      return 0
    }
    return OnboardingTiming.easeOut((time - OnboardingTiming.decayStart) / OnboardingTiming.flashDecay)
  }

  var markScale: CGFloat {
    0.9 + 0.1 * CGFloat(markOpacity)
  }

  var glow: Double {
    guard markOpacity > 0.05 else {
      return 0
    }
    let breath = sin(time / OnboardingTiming.glowBreath * .pi * 2 - .pi / 2) * 0.5 + 0.5
    return 0.22 + 0.18 * breath
  }

  /// Background visibility. Nothing shows until the flash starts to decay.
  var atmosphere: Double {
    if reduceMotion {
      return OnboardingTiming.clamp(time / OnboardingTiming.reducedCrossfade)
    }
    return markOpacity
  }
}

/// Beam, collapse, and flash drawn additively in one canvas at 60 fps.
private struct OnboardingBeamCanvas: View {
  var clock: OnboardingRevealClock

  var body: some View {
    Canvas(rendersAsynchronously: false) { canvas, size in
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      if clock.beamVisible {
        let head = CGPoint(x: center.x * clock.beamProgress, y: center.y)
        let open = 1 - clock.collapse
        OnboardingBeamPainter.drawTrail(&canvas, head: head, open: open)
        OnboardingBeamPainter.drawHead(&canvas, head: head, open: open, charge: clock.collapse)
      }
      if clock.flash > 0 {
        OnboardingBeamPainter.drawFlash(&canvas, size: size, flash: clock.flash, spread: clock.flashSpread)
      }
    }
    .allowsHitTesting(false)
  }
}

enum OnboardingBeamPainter {
  /// A soft blue wake and a thin bright line, both fading toward the left.
  static func drawTrail(_ context: inout GraphicsContext, head: CGPoint, open: CGFloat) {
    let length = min(head.x, 340) * open
    guard length > 1 else {
      return
    }
    let start = CGPoint(x: head.x - length, y: head.y)
    context.drawLayer { layer in
      layer.blendMode = .plusLighter
      layer.addFilter(.blur(radius: 14))
      let wake = Gradient(colors: [.clear, OnboardingColor.beam.opacity(0.10), OnboardingColor.beam.opacity(0.45)])
      layer.fill(
        Path(CGRect(x: start.x, y: head.y - 16, width: length, height: 32)),
        with: .linearGradient(wake, startPoint: start, endPoint: head)
      )
    }
    context.drawLayer { layer in
      layer.blendMode = .plusLighter
      layer.addFilter(.blur(radius: 2))
      let line = Gradient(colors: [.clear, OnboardingColor.beam.opacity(0.35), .white.opacity(0.95)])
      layer.fill(
        Path(CGRect(x: start.x, y: head.y - 1.5, width: length, height: 3)),
        with: .linearGradient(line, startPoint: start, endPoint: head)
      )
    }
  }

  /// Elliptical blue glow around the head, a bloomed core, and a crisp white core.
  /// As `open` falls to 0 the head pinches to a point while `charge` brightens it.
  static func drawHead(_ context: inout GraphicsContext, head: CGPoint, open: CGFloat, charge: CGFloat) {
    let glowWidth = 60 + 220 * open
    let glowHeight = 30 + 90 * open
    context.drawLayer { layer in
      layer.blendMode = .plusLighter
      layer.translateBy(x: head.x, y: head.y)
      layer.scaleBy(x: glowWidth / glowHeight, y: 1)
      let radius = glowHeight / 2
      let glow = Gradient(colors: [
        OnboardingColor.beam.opacity(0.55 + 0.35 * Double(charge)),
        OnboardingColor.beam.opacity(0.18),
        .clear,
      ])
      layer.fill(
        Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(glow, center: .zero, startRadius: 0, endRadius: radius)
      )
    }
    context.drawLayer { layer in
      layer.blendMode = .plusLighter
      layer.addFilter(.blur(radius: 4))
      let width = 6 + 36 * open
      layer.fill(
        Path(roundedRect: CGRect(x: head.x - width / 2, y: head.y - 2.5, width: width, height: 5), cornerRadius: 2.5),
        with: .color(.white.opacity(0.9))
      )
    }
    let width = 4 + 30 * open
    context.fill(
      Path(roundedRect: CGRect(x: head.x - width / 2, y: head.y - 1.2, width: width, height: 2.4), cornerRadius: 1.2),
      with: .color(.white)
    )
  }

  /// A white bloom that grows from the center point, over a full-window wash.
  static func drawFlash(_ context: inout GraphicsContext, size: CGSize, flash: Double, spread: Double) {
    let center = CGPoint(x: size.width / 2, y: size.height / 2)
    let radius = 140 + max(size.width, size.height) * 0.75 * CGFloat(spread)
    context.drawLayer { layer in
      layer.blendMode = .plusLighter
      let bloom = Gradient(colors: [
        .white.opacity(flash),
        .white.opacity(flash * 0.55),
        OnboardingColor.beam.opacity(flash * 0.35),
        .clear,
      ])
      layer.fill(
        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
        with: .radialGradient(bloom, center: center, startRadius: 0, endRadius: radius)
      )
    }
    let wash = pow(flash, 1.4) * 0.9
    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white.opacity(wash)))
  }
}

import SpriteKit
import SwiftUI

/// SpriteKit draws the pieces. Motion is a small integrator of our own (initial
/// velocity, gravity, air drag, spin, and flutter) rather than a physics world,
/// so every part of the fall is tunable from `OnboardingTiming.Confetti`.
struct OnboardingConfettiView: View {
  var started: Date
  var reduceMotion: Bool

  var body: some View {
    Group {
      if reduceMotion {
        OnboardingReducedCelebration(started: started)
      } else {
        OnboardingConfettiHost(started: started)
      }
    }
    .allowsHitTesting(false)
  }
}

private struct OnboardingConfettiHost: NSViewRepresentable {
  var started: Date

  func makeNSView(context _: Context) -> SKView {
    let view = SKView(frame: NSRect(origin: .zero, size: OnboardingChrome.size))
    view.allowsTransparency = true
    view.ignoresSiblingOrder = true
    view.preferredFramesPerSecond = 60
    let scene = OnboardingConfettiScene(size: OnboardingChrome.size)
    scene.scaleMode = .resizeFill
    scene.backgroundColor = .clear
    scene.started = started
    view.presentScene(scene)
    return view
  }

  func updateNSView(_: SKView, context _: Context) {}
}

final class OnboardingConfettiScene: SKScene {
  var started = Date()
  private var pieces: [OnboardingConfettiPiece] = []
  private var lastFrame: TimeInterval?
  private var spawned = false
  private var done = false

  override func didMove(to view: SKView) {
    super.didMove(to: view)
    backgroundColor = .clear
    spawnIfNeeded()
  }

  override func didChangeSize(_ oldSize: CGSize) {
    super.didChangeSize(oldSize)
    spawnIfNeeded()
  }

  override func update(_ currentTime: TimeInterval) {
    super.update(currentTime)
    guard !done else {
      return
    }
    let elapsed = Date().timeIntervalSince(started)
    let step = min(1.0 / 30.0, currentTime - (lastFrame ?? currentTime))
    lastFrame = currentTime
    if elapsed >= OnboardingTiming.confetti {
      done = true
      removeAllChildren()
      pieces.removeAll()
      return
    }
    let fadeStart = OnboardingTiming.confetti - OnboardingTiming.confettiFade
    let alpha = elapsed <= fadeStart
      ? 1
      : max(0, 1 - (elapsed - fadeStart) / OnboardingTiming.confettiFade)
    for index in pieces.indices {
      pieces[index].advance(by: step, elapsed: elapsed)
      pieces[index].node.alpha = alpha
    }
  }

  private func spawnIfNeeded() {
    guard !spawned, size.width > 20, size.height > 20 else {
      return
    }
    spawned = true
    var random = OnboardingStarRandom(seed: 0x434f_4e46)
    let origin = CGPoint(x: size.width / 2, y: size.height / 2)
    for index in 0 ..< OnboardingTiming.Confetti.count {
      let piece = OnboardingConfettiPiece(index: index, origin: origin, random: &random)
      addChild(piece.node)
      pieces.append(piece)
    }
  }
}

/// One rectangle or circle and the state its motion needs.
struct OnboardingConfettiPiece {
  let node: SKNode
  private var position: CGPoint
  private var velocity: CGVector
  private var rotation: CGFloat
  private let spin: CGFloat
  private let drag: CGFloat
  private let flutterPhase: Double
  private let flutterRate: Double
  private let tumblePhase: Double
  private let tumbleRate: Double

  init(index: Int, origin: CGPoint, random: inout OnboardingStarRandom) {
    typealias Tuning = OnboardingTiming.Confetti
    let span = Tuning.minSize + CGFloat(random.next()) * (Tuning.maxSize - Tuning.minSize)
    let color = Self.palette[index % Self.palette.count]
    if random.next() < Tuning.circleShare {
      node = Self.circle(diameter: span, color: color)
    } else {
      let height = span * (0.45 + CGFloat(random.next()) * 0.5)
      node = Self.rectangle(size: CGSize(width: span, height: height), color: color)
    }
    position = origin
    let angle = random.next() * .pi * 2
    let speed = Tuning.minSpeed + CGFloat(random.next()) * (Tuning.maxSpeed - Tuning.minSpeed)
    velocity = CGVector(
      dx: CGFloat(cos(angle)) * speed,
      dy: CGFloat(sin(angle)) * speed * 0.8 + Tuning.lift
    )
    rotation = CGFloat(random.next()) * .pi
    spin = (CGFloat(random.next()) * 2 - 1) * Tuning.maxSpin
    drag = Tuning.minDrag + CGFloat(random.next()) * (Tuning.maxDrag - Tuning.minDrag)
    flutterPhase = random.next() * .pi * 2
    flutterRate = 5 + random.next() * 5
    tumblePhase = random.next() * .pi * 2
    tumbleRate = 4 + random.next() * 6
    node.position = position
    node.zRotation = rotation
  }

  mutating func advance(by interval: TimeInterval, elapsed: TimeInterval) {
    typealias Tuning = OnboardingTiming.Confetti
    let step = CGFloat(interval)
    velocity.dy -= Tuning.gravity * step
    let damping = CGFloat(exp(-Double(drag) * interval))
    velocity.dx *= damping
    velocity.dy *= damping
    let flutter = CGFloat(sin(elapsed * flutterRate + flutterPhase)) * Tuning.flutterSwing
    position.x += (velocity.dx + flutter) * step
    position.y += velocity.dy * step
    rotation += spin * step
    node.position = position
    node.zRotation = rotation
    // A flat piece seen edge-on: squash the height as it tumbles.
    node.yScale = 0.25 + 0.75 * abs(CGFloat(cos(elapsed * tumbleRate + tumblePhase)))
  }

  private static func rectangle(size: CGSize, color: SKColor) -> SKNode {
    let node = SKSpriteNode(color: color, size: size)
    node.colorBlendFactor = 1
    return node
  }

  private static func circle(diameter: CGFloat, color: SKColor) -> SKNode {
    let node = SKShapeNode(circleOfRadius: diameter / 2)
    node.fillColor = color
    node.strokeColor = .clear
    node.isAntialiased = true
    return node
  }

  /// Four muted tones from the launcher palette. No rainbow.
  private static let palette: [SKColor] = [
    SKColor(srgbRed: 0.55, green: 0.74, blue: 0.92, alpha: 1),
    SKColor(srgbRed: 0.30, green: 0.46, blue: 0.68, alpha: 1),
    SKColor(srgbRed: 0.86, green: 0.90, blue: 0.95, alpha: 1),
    SKColor(srgbRed: 0.62, green: 0.60, blue: 0.88, alpha: 1),
  ]
}

/// Reduce Motion: a soft blue glow that rises and fades in place of the burst.
private struct OnboardingReducedCelebration: View {
  var started: Date

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
      let progress = OnboardingTiming.clamp(context.date.timeIntervalSince(started) / OnboardingTiming.confetti)
      let alpha = sin(progress * .pi) * 0.4
      Canvas(rendersAsynchronously: false) { canvas, size in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius: CGFloat = 260
        canvas.blendMode = .plusLighter
        canvas.fill(
          Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
          with: .radialGradient(
            Gradient(colors: [OnboardingColor.beam.opacity(alpha), .clear]),
            center: center,
            startRadius: 0,
            endRadius: radius
          )
        )
      }
    }
  }
}

import SpriteKit
import SwiftUI

/// Muted rectangles and circles. SpriteKit supplies gravity, drag, and spin
/// without a flat SwiftUI tween.
struct OnboardingBurstView: View {
  var started: Date

  var body: some View {
    OnboardingBurstHost(started: started)
      .allowsHitTesting(false)
  }
}

private struct OnboardingBurstHost: NSViewRepresentable {
  var started: Date

  func makeNSView(context _: Context) -> SKView {
    let view = SKView(frame: NSRect(origin: .zero, size: OnboardingChrome.size))
    view.allowsTransparency = true
    view.ignoresSiblingOrder = true
    let scene = OnboardingBurstScene(size: OnboardingChrome.size)
    scene.scaleMode = .resizeFill
    scene.backgroundColor = .clear
    scene.started = started
    view.presentScene(scene)
    return view
  }

  func updateNSView(_: SKView, context _: Context) {}
}

final class OnboardingBurstScene: SKScene {
  var started = Date()
  private var didSpawn = false
  private var bits: [SKShapeNode] = []

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
    let elapsed = Date().timeIntervalSince(started)
    let fadeStart = OnboardingTiming.burst - OnboardingTiming.burstFade
    let alpha = elapsed <= fadeStart
      ? 1
      : max(0, 1 - (elapsed - fadeStart) / OnboardingTiming.burstFade)
    for node in bits {
      node.alpha = alpha
      let phase = (node.userData?["flutter"] as? NSNumber)?.doubleValue ?? 0
      node.physicsBody?.applyForce(CGVector(dx: sin(elapsed * 6 + phase) * 16, dy: 0))
    }
  }

  private func spawnIfNeeded() {
    guard !didSpawn, size.width > 20, size.height > 20 else {
      return
    }
    didSpawn = true
    physicsWorld.gravity = CGVector(dx: 0, dy: -480)
    var random = OnboardingStarRandom(seed: 0x4255_5253)
    let origin = CGPoint(x: size.width / 2, y: size.height / 2)
    for index in 0 ..< 84 {
      let node = makeBit(index: index, random: &random, origin: origin)
      addChild(node)
      bits.append(node)
    }
  }

  private func makeBit(index: Int, random: inout OnboardingStarRandom, origin: CGPoint) -> SKShapeNode {
    let span = 4 + CGFloat(random.next()) * 4
    let circle = random.next() > 0.48
    let node = circle
      ? SKShapeNode(circleOfRadius: span / 2)
      : SKShapeNode(
        rectOf: CGSize(width: span, height: span * (0.42 + CGFloat(random.next()) * 0.7)),
        cornerRadius: 1
      )
    node.fillColor = Self.palette[index % Self.palette.count]
    node.strokeColor = .clear
    node.position = origin
    node.zRotation = CGFloat(random.next()) * .pi
    let body = circle
      ? SKPhysicsBody(circleOfRadius: span / 2)
      : SKPhysicsBody(rectangleOf: CGSize(width: span, height: span * 0.6))
    body.affectedByGravity = true
    body.linearDamping = 0.55
    body.angularDamping = 0.35
    body.friction = 0
    body.restitution = 0.12
    body.allowsRotation = true
    let angle = random.next() * Double.pi * 2
    let speed = 240 + random.next() * 340
    body.velocity = CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed * 0.72 + 90)
    body.angularVelocity = CGFloat(random.next() * 9 - 4.5)
    node.physicsBody = body
    node.userData = ["flutter": random.next() * .pi * 2]
    return node
  }

  private static let palette: [SKColor] = [
    SKColor(srgbRed: 0.55, green: 0.74, blue: 0.92, alpha: 0.92),
    SKColor(srgbRed: 0.27, green: 0.45, blue: 0.66, alpha: 0.95),
    SKColor(srgbRed: 0.84, green: 0.89, blue: 0.94, alpha: 0.88),
    SKColor(srgbRed: 0.15, green: 0.26, blue: 0.42, alpha: 0.95),
  ]
}

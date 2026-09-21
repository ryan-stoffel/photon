import Foundation

/// Cheap duration log for launcher snappiness. Silent unless `PHOTON_DEBUG=1`.
public enum PhotonTiming: Sendable {
  public static var isEnabled: Bool {
    ProcessInfo.processInfo.environment["PHOTON_DEBUG"] == "1"
  }

  public static func start() -> ContinuousClock.Instant? {
    guard isEnabled else {
      return nil
    }
    return .now
  }

  public static func milliseconds(from start: ContinuousClock.Instant, to end: ContinuousClock.Instant = .now)
    -> Double
  {
    let elapsed = start.duration(to: end)
    return Double(elapsed.components.seconds) * 1_000
      + Double(elapsed.components.attoseconds) / 1e15
  }

  public static func end(_ label: String, from start: ContinuousClock.Instant?) {
    guard isEnabled, let start else {
      return
    }
    let ms = milliseconds(from: start)
    NSLog("PhotonTiming: %@ %.1fms", label, ms)
  }
}

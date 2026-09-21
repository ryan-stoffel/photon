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

  public static func milliseconds(
    from start: ContinuousClock.Instant,
    to end: ContinuousClock.Instant = .now
  ) -> Double {
    let elapsed = start.duration(to: end)
    let millisecondAttoseconds = 1_000_000_000_000_000.0
    return Double(elapsed.components.seconds) * 1000
      + Double(elapsed.components.attoseconds) / millisecondAttoseconds
  }

  public static func end(_ label: String, from start: ContinuousClock.Instant?) {
    guard isEnabled, let start else {
      return
    }
    let ms = milliseconds(from: start)
    NSLog("PhotonTiming: %@ %.1fms", label, ms)
  }
}

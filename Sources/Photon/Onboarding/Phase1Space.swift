import AppKit
import Darwin
import Foundation

/// Dev builds can park Phase 1 on one desktop with PHOTON_PHASE1_SPACE.
/// The overlay does not follow the active space.
enum Phase1Space {
  static var requestedDesktop: Int? {
    guard PhotonProduct.isDev else {
      return nil
    }
    guard let raw = ProcessInfo.processInfo.environment["PHOTON_PHASE1_SPACE"] else {
      return nil
    }
    return Int(raw)
  }

  static func pin(_ window: NSWindow) -> Bool {
    guard let desktop = requestedDesktop, desktop > 0, let uuid = spaceUUID(desktop: desktop) else {
      return false
    }
    guard move(window, to: uuid) else {
      return false
    }
    Thread.sleep(forTimeInterval: 0.05)
    return !isOnCurrentScreen(window)
  }

  private static func spaceUUID(desktop: Int) -> String? {
    let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as NSArray
    for case let display as NSDictionary in displays {
      let spaces = display["Spaces"] as? NSArray ?? []
      let index = desktop - 1
      guard index >= 0, index < spaces.count, let space = spaces[index] as? NSDictionary else {
        continue
      }
      return space["uuid"] as? String
    }
    return nil
  }

  private static func move(_ window: NSWindow, to uuid: String) -> Bool {
    guard window.windowNumber > 0, let sky = dlopen(skyLight, RTLD_LAZY) else {
      return false
    }
    guard let moveSymbol = dlsym(sky, "SLSMoveWindowsToManagedSpace"),
          let connectionSymbol = dlsym(sky, "SLSMainConnectionID")
    else {
      return false
    }
    typealias Move = @convention(c) (Int32, CFArray, CFString) -> Void
    typealias Connection = @convention(c) () -> Int32
    let moveWindow = unsafeBitCast(moveSymbol, to: Move.self)
    let connection = unsafeBitCast(connectionSymbol, to: Connection.self)
    var identifier = Int32(window.windowNumber)
    guard let number = CFNumberCreate(nil, .sInt32Type, &identifier) else {
      return false
    }
    moveWindow(connection(), [number] as CFArray, uuid as CFString)
    return true
  }

  private static func isOnCurrentScreen(_ window: NSWindow) -> Bool {
    let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    return info.contains { ($0[kCGWindowNumber as String] as? Int) == window.windowNumber }
  }

  private static let skyLight = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
}

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

@_silgen_name("CGSCopyManagedDisplaySpaces")
private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray

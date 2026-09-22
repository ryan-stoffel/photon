import AppKit
import Darwin
import Foundation

/// Dev builds can park Phase 1 on one desktop with PHOTON_PHASE1_SPACE.
/// The overlay does not follow the active space.
@MainActor
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
    guard let desktop = requestedDesktop, desktop > 0, let target = space(desktop: desktop) else {
      return false
    }
    guard move(window, to: target.id) else {
      return false
    }
    Thread.sleep(forTimeInterval: 0.15)
    let ids = spaceIDs(for: window)
    let parked = ids.contains(target.id) && !isOnCurrentScreen(window)
    let note = "target \(target.id) spaces \(ids) parked \(parked)\n"
    try? note.write(toFile: "/tmp/photon-phase1-space.txt", atomically: true, encoding: .utf8)
    return parked
  }

  private static func space(desktop: Int) -> (uuid: String, id: UInt64)? {
    let displays = CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as NSArray
    for case let display as NSDictionary in displays {
      let spaces = display["Spaces"] as? NSArray ?? []
      let index = desktop - 1
      guard index >= 0, index < spaces.count, let space = spaces[index] as? NSDictionary else {
        continue
      }
      guard let uuid = space["uuid"] as? String else {
        continue
      }
      let raw = (space["id64"] as? NSNumber)?.uint64Value ?? (space["ManagedSpaceID"] as? NSNumber)?.uint64Value
      guard let raw else {
        continue
      }
      return (uuid, raw)
    }
    return nil
  }

  private static func spaceIDs(for window: NSWindow) -> [UInt64] {
    guard window.windowNumber > 0,
          let sky = dlopen(skyLight, RTLD_LAZY),
          let symbol = dlsym(sky, "SLSCopySpacesForWindows"),
          let connectionSymbol = dlsym(sky, "SLSMainConnectionID")
    else {
      return []
    }
    typealias Copy = @convention(c) (Int32, Int32, CFArray) -> CFArray
    typealias Connection = @convention(c) () -> Int32
    let copy = unsafeBitCast(symbol, to: Copy.self)
    let connection = unsafeBitCast(connectionSymbol, to: Connection.self)
    var identifier = Int32(window.windowNumber)
    guard let number = CFNumberCreate(nil, .sInt32Type, &identifier) else {
      return []
    }
    let spaces = copy(connection(), 0x7, [number] as CFArray) as NSArray
    return spaces.compactMap { ($0 as? NSNumber)?.uint64Value }
  }

  private static func move(_ window: NSWindow, to space: UInt64) -> Bool {
    guard window.windowNumber > 0, let sky = dlopen(skyLight, RTLD_LAZY) else {
      return false
    }
    guard let moveSymbol = dlsym(sky, "SLSMoveWindowsToManagedSpace"),
          let connectionSymbol = dlsym(sky, "SLSMainConnectionID")
    else {
      return false
    }
    typealias Move = @convention(c) (Int32, CFArray, UInt64) -> Void
    typealias Connection = @convention(c) () -> Int32
    let moveWindow = unsafeBitCast(moveSymbol, to: Move.self)
    let connection = unsafeBitCast(connectionSymbol, to: Connection.self)
    var identifier = Int32(window.windowNumber)
    guard let number = CFNumberCreate(nil, .sInt32Type, &identifier) else {
      return false
    }
    moveWindow(connection(), [number] as CFArray, space)
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

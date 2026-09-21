import Foundation
import IOKit
import IOKit.hidsystem

/// Reads and writes the Caps Lock lock state through IOHIDSystem.
///
/// Needed because remapping Caps Lock to F18 with `hidutil` still lets macOS toggle the lock
/// on some machines. Photon forces the lock off while Caps Lock is the Hyper key, except when
/// the user has chosen the tap behaviour "Toggle Caps Lock".
public enum CapsLockState {
  public static var isOn: Bool {
    withConnect { _, connect in
      var state = false
      guard IOHIDGetModifierLockState(connect, Int32(kIOHIDCapsLockState), &state) == KERN_SUCCESS else {
        return false
      }
      return state
    } ?? false
  }

  public static func set(_ on: Bool) {
    _ = withConnect { _, connect in
      IOHIDSetModifierLockState(connect, Int32(kIOHIDCapsLockState), on)
    }
  }

  public static func forceOff() {
    if isOn {
      set(false)
    }
  }

  static func toggle() {
    set(!isOn)
  }

  private static func withConnect<T>(_ body: (io_service_t, io_connect_t) -> T) -> T? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
    guard service != 0 else {
      return nil
    }
    defer { IOObjectRelease(service) }

    var connect: io_connect_t = 0
    guard IOServiceOpen(service, mach_task_self_, UInt32(kIOHIDParamConnectType), &connect) == KERN_SUCCESS else {
      return nil
    }
    defer { IOServiceClose(connect) }
    return body(service, connect)
  }
}

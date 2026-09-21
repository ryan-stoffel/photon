import PhotonKeybinds
import XCTest

final class CapsLockStateTests: XCTestCase {
  func testForceOffDoesNotCrash() {
    CapsLockState.forceOff()
    XCTAssertFalse(CapsLockState.isOn)
  }
}

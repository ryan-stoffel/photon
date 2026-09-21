import CoreGraphics
import XCTest
@testable import PhotonKeybinds

final class HyperKeyEngineTests: XCTestCase {
  func testHyperDownForcesCapsLockOffWhenSuppressed() {
    let engine = HyperKeyEngine()
    let forced = Counter()
    engine.onSuppressCapsLock = { forced.increment() }
    engine.update(HyperKeyEngine.Configuration(suppressCapsLock: true))

    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 79, keyDown: true) else {
      XCTFail("could not create key event")
      return
    }
    let result = engine.handle(type: .keyDown, event: down)
    XCTAssertNil(result)
    XCTAssertEqual(forced.value, 1)
  }

  func testCapsLockKeyCodeIsTreatedAsHyperWhenSuppressed() {
    let engine = HyperKeyEngine()
    let forced = Counter()
    engine.onSuppressCapsLock = { forced.increment() }
    engine.update(HyperKeyEngine.Configuration(suppressCapsLock: true))

    guard let down = CGEvent(
      keyboardEventSource: nil,
      virtualKey: HyperKeyEngine.capsLockKeyCode,
      keyDown: true
    ) else {
      XCTFail("could not create Caps Lock event")
      return
    }
    XCTAssertNil(engine.handle(type: .keyDown, event: down))
    XCTAssertEqual(forced.value, 1)
  }

  func testFlagsChangedClearsCapsLockWhenSuppressed() {
    let engine = HyperKeyEngine()
    let forced = Counter()
    engine.onSuppressCapsLock = { forced.increment() }
    engine.update(HyperKeyEngine.Configuration(suppressCapsLock: true))

    guard let event = CGEvent(keyboardEventSource: nil, virtualKey: HyperKeyEngine.capsLockKeyCode, keyDown: false)
    else {
      XCTFail("could not create flagsChanged event")
      return
    }
    event.flags = .maskAlphaShift
    XCTAssertNil(engine.handle(type: .flagsChanged, event: event))
    XCTAssertEqual(forced.value, 1)
    XCTAssertFalse(event.flags.contains(.maskAlphaShift))
  }

  func testDoesNotForceCapsLockOffWhenNotSuppressed() {
    let engine = HyperKeyEngine()
    let forced = Counter()
    engine.onSuppressCapsLock = { forced.increment() }
    engine.update(HyperKeyEngine.Configuration(suppressCapsLock: false))

    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 79, keyDown: true) else {
      XCTFail("could not create key event")
      return
    }
    XCTAssertNil(engine.handle(type: .keyDown, event: down))
    XCTAssertEqual(forced.value, 0)
  }
}

private final class Counter: @unchecked Sendable {
  private let lock = NSLock()
  private var count = 0

  var value: Int {
    lock.withLock { count }
  }

  func increment() {
    lock.withLock { count += 1 }
  }
}

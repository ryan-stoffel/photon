import CoreGraphics
import XCTest
@testable import PhotonKeybinds

final class HyperKeyEngineTests: XCTestCase {
  func testHyperDownForcesCapsLockOffWhenSuppressed() {
    let engine = HyperKeyEngine()
    let forced = Counter()
    engine.onSuppressCapsLock = { _ in forced.increment() }
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
    engine.onSuppressCapsLock = { _ in forced.increment() }
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
    engine.onSuppressCapsLock = { _ in forced.increment() }
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
    engine.onSuppressCapsLock = { _ in forced.increment() }
    engine.update(HyperKeyEngine.Configuration(suppressCapsLock: false))

    guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 79, keyDown: true) else {
      XCTFail("could not create key event")
      return
    }
    XCTAssertNil(engine.handle(type: .keyDown, event: down))
    XCTAssertEqual(forced.value, 0)
  }

  func testToggleTapLatchesCapsLockOnAndSuppressionKeepsIt() throws {
    let engine = HyperKeyEngine()
    let requested = Recorder()
    engine.onSuppressCapsLock = { requested.append($0) }
    engine.update(HyperKeyEngine.Configuration(tapBehavior: .capsLock, suppressCapsLock: true))

    let down = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 79, keyDown: true))
    let up = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 79, keyDown: false))
    XCTAssertNil(engine.handle(type: .keyDown, event: down))
    XCTAssertNil(engine.handle(type: .keyUp, event: up))
    XCTAssertEqual(requested.values, [false, true])

    // A Shift press while latched on carries the Caps Lock flag and must keep it.
    let shift = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 56, keyDown: true))
    shift.flags = .maskAlphaShift
    XCTAssertNotNil(engine.handle(type: .flagsChanged, event: shift))
    XCTAssertTrue(shift.flags.contains(.maskAlphaShift))
    XCTAssertEqual(requested.values, [false, true])

    XCTAssertNil(engine.handle(type: .keyDown, event: down))
    XCTAssertNil(engine.handle(type: .keyUp, event: up))
    XCTAssertEqual(requested.values, [false, true, true, false])
  }

  func testDisabledTapReleasesAHeldHyperKey() throws {
    let engine = HyperKeyEngine()
    let down = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 79, keyDown: true))
    XCTAssertNil(engine.handle(type: .keyDown, event: down))
    _ = engine.handle(type: .tapDisabledByTimeout, event: down)

    let letter = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true))
    let result = try XCTUnwrap(engine.handle(type: .keyDown, event: letter))
    XCTAssertFalse(KeyModifiers(cgEventFlags: result.takeUnretainedValue().flags.rawValue).isHyper)
  }
}

private final class Recorder: @unchecked Sendable {
  private let lock = NSLock()
  private var list: [Bool] = []

  var values: [Bool] {
    lock.withLock { list }
  }

  func append(_ value: Bool) {
    lock.withLock { list.append(value) }
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

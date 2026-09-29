import Foundation
import PhotonKeybinds
import XCTest

final class PermissionDialogGateTests: XCTestCase {
  func testOrderIsAccessibilityThenInputMonitoring() {
    XCTAssertEqual(
      LaunchPermissionOrder.prompts,
      [.accessibility, .inputMonitoring]
    )
  }

  func testWaitsUntilAPromptAppears() {
    let phase = PermissionDialogGate.advance(
      phase: .waitingToAppear,
      granted: false,
      baseline: [],
      windows: [],
      appearTimedOut: false
    )
    XCTAssertEqual(phase, .waitingToAppear)
  }

  func testFinishesWhenNoDialogAppears() {
    let phase = PermissionDialogGate.advance(
      phase: .waitingToAppear,
      granted: false,
      baseline: [],
      windows: [],
      appearTimedOut: true
    )
    XCTAssertEqual(phase, .finished)
  }

  func testNewPromptSizedWindowHoldsTheNextPrompt() {
    let phase = PermissionDialogGate.advance(
      phase: .waitingToAppear,
      granted: false,
      baseline: [1],
      windows: [prompt(id: 1, width: 520, height: 440), prompt(id: 8, width: 480, height: 180)],
      appearTimedOut: false
    )
    XCTAssertEqual(phase, .waitingToClose)
  }

  func testClosingTheDialogFinishesTheWait() {
    let phase = PermissionDialogGate.advance(
      phase: .waitingToClose,
      granted: false,
      baseline: [1],
      windows: [prompt(id: 1, width: 520, height: 440)],
      appearTimedOut: false
    )
    XCTAssertEqual(phase, .finished)
  }

  func testGrantFinishesEvenIfTheDialogIsStillVisible() {
    let phase = PermissionDialogGate.advance(
      phase: .waitingToClose,
      granted: true,
      baseline: [],
      windows: [prompt(id: 8, width: 480, height: 180)],
      appearTimedOut: false
    )
    XCTAssertEqual(phase, .finished)
  }

  func testIgnoresWindowsThatAreNotPrompts() {
    let tiny = PermissionDialogWindow(id: 3, width: 120, height: 40, ownerName: "Notification", title: "")
    let settings = PermissionDialogWindow(
      id: 4,
      width: 980,
      height: 700,
      ownerName: "System Settings",
      title: "Accessibility"
    )
    let ids = PermissionDialogGate.appearedIDs(baseline: [], windows: [tiny, settings])
    XCTAssertTrue(ids.isEmpty)
  }

  func testKnownPromptProcessCountsEvenWhenShort() {
    let dialog = PermissionDialogWindow(
      id: 9,
      width: 420,
      height: 90,
      ownerName: "universalAccessAuthWarn",
      title: ""
    )
    XCTAssertTrue(PermissionDialogGate.isSystemPrompt(dialog))
  }

  @MainActor
  func testPromptsDoNotOverlap() async {
    let runner = LaunchPermissionRunner()
    var events: [String] = []
    var inFlight = 0
    var maxInFlight = 0
    await runner.run { prompt in
      inFlight += 1
      maxInFlight = max(maxInFlight, inFlight)
      events.append("start-\(prompt.rawValue)")
      try? await Task.sleep(nanoseconds: 20_000_000)
      events.append("end-\(prompt.rawValue)")
      inFlight -= 1
    }
    XCTAssertEqual(maxInFlight, 1)
    XCTAssertEqual(
      events,
      [
        "start-accessibility",
        "end-accessibility",
        "start-inputMonitoring",
        "end-inputMonitoring",
      ]
    )
  }

  private func prompt(id: UInt32, width: Double, height: Double) -> PermissionDialogWindow {
    PermissionDialogWindow(id: id, width: width, height: height, ownerName: "tccd", title: "")
  }
}

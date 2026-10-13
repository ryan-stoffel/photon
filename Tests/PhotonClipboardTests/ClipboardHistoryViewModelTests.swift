#if canImport(AppKit)
import Foundation
import PhotonClipboard
import XCTest

@MainActor
final class ClipboardHistoryViewModelTests: XCTestCase {
  func testNewQuerySelectsTopRowAndPagingClamps() async throws {
    let model = try await makeModel(newestLast: ["apple pie", "apple tart", "banana"])
    model.moveSelection(2)
    XCTAssertEqual(model.selectedItem?.text, "apple pie")

    model.query = "apple"
    XCTAssertEqual(model.selectedItem?.text, "apple tart", "a new query starts on the top row")

    model.moveSelection(10)
    XCTAssertEqual(model.selectedItem?.text, "apple pie", "Page Down stops at the last row")
  }

  func testDeletingAnotherRowKeepsTheSelection() async throws {
    let model = try await makeModel(newestLast: ["apple pie", "apple tart", "banana"])
    model.moveSelection(1)
    let banana = try XCTUnwrap(model.results.first)

    model.delete(banana)
    XCTAssertEqual(model.selectedItem?.text, "apple tart")
    try await waitForItems(count: 2, in: model.manager)
    XCTAssertEqual(model.selectedItem?.text, "apple tart", "the store update keeps the selection")
  }

  /// A model over a stored history with history capture off, so no pasteboard monitor runs.
  private func makeModel(newestLast texts: [String]) async throws -> ClipboardHistoryViewModel {
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("photon-clipboard-model-\(UUID().uuidString)", isDirectory: true)
    let settings = ClipboardSettings(isEnabled: false, retention: .forever)
    let store = ClipboardStore(directory: directory)
    let now = Date()
    for (index, text) in texts.enumerated() {
      let date = now.addingTimeInterval(Double(index - texts.count) * 10)
      _ = await store.insert(ClipboardCapture(text: text, date: date), settings: settings)
    }
    let manager = ClipboardManager(settings: settings, directory: directory)
    addTeardownBlock { @MainActor in
      manager.stop()
      try? FileManager.default.removeItem(at: directory)
    }
    manager.start()
    try await waitForItems(count: texts.count, in: manager)
    return ClipboardHistoryViewModel(manager: manager)
  }

  private func waitForItems(count: Int, in manager: ClipboardManager) async throws {
    for _ in 0 ..< 200 where manager.items.count != count {
      try await Task.sleep(for: .milliseconds(10))
    }
    XCTAssertEqual(manager.items.count, count)
  }
}
#endif

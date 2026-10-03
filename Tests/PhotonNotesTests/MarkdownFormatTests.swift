import Foundation
import PhotonNotes
import XCTest

final class MarkdownFormatTests: XCTestCase {
  func testBoldWrapsTheSelection() {
    let edit = MarkdownFormat.apply(.bold, to: "hello world", selection: NSRange(location: 6, length: 5))
    XCTAssertEqual(edit.text, "hello **world**")
    XCTAssertEqual(edit.selection, NSRange(location: 8, length: 5))
  }

  func testEmptySelectionInsertsMarkers() {
    let edit = MarkdownFormat.apply(.italic, to: "ab", selection: NSRange(location: 1, length: 0))
    XCTAssertEqual(edit.text, "a**b")
    XCTAssertEqual(edit.selection.location, 2)
    XCTAssertEqual(edit.selection.length, 0)
  }

  func testHeadingReplacesExistingMarker() {
    let edit = MarkdownFormat.apply(.heading(2), to: "# Title", selection: NSRange(location: 2, length: 0))
    XCTAssertEqual(edit.text, "## Title")
    let same = MarkdownFormat.apply(.heading(2), to: edit.text, selection: edit.selection)
    XCTAssertEqual(same.text, "Title", "the same level toggles the heading off")
  }

  func testChecklistPrefixesTheLine() {
    let edit = MarkdownFormat.apply(.checklist, to: "Buy milk", selection: NSRange(location: 0, length: 0))
    XCTAssertEqual(edit.text, "- [ ] Buy milk")
  }

  func testCodeBlockFencesTheSelectedLines() {
    let edit = MarkdownFormat.apply(.codeBlock, to: "a\nlet x\nb", selection: NSRange(location: 2, length: 5))
    XCTAssertEqual(edit.text, "a\n```\nlet x\n```\nb")
    XCTAssertEqual(edit.selection, NSRange(location: 6, length: 5))
    let empty = MarkdownFormat.apply(.codeBlock, to: "", selection: NSRange(location: 0, length: 0))
    XCTAssertEqual(empty.text, "```\n\n```")
    XCTAssertEqual(empty.selection, NSRange(location: 4, length: 0))
  }

  func testWrapUnwrapsWhenMarkersAreAlreadyThere() {
    let selected = MarkdownFormat.apply(.bold, to: "**x**", selection: NSRange(location: 0, length: 5))
    XCTAssertEqual(selected.text, "x")
    let inside = MarkdownFormat.apply(.bold, to: "a **x** b", selection: NSRange(location: 4, length: 1))
    XCTAssertEqual(inside.text, "a x b")
    XCTAssertEqual(inside.selection, NSRange(location: 2, length: 1))
    let italicOnBold = MarkdownFormat.apply(.italic, to: "**x**", selection: NSRange(location: 2, length: 1))
    XCTAssertEqual(italicOnBold.text, "***x***", "italic must not take one star of bold")
  }

  func testListMarkersApplyToEveryLineAndToggleOff() {
    let lines = MarkdownFormat.apply(.bulletList, to: "a\nb\nc", selection: NSRange(location: 0, length: 5))
    XCTAssertEqual(lines.text, "- a\n- b\n- c")
    let removed = MarkdownFormat.apply(.bulletList, to: lines.text, selection: lines.selection)
    XCTAssertEqual(removed.text, "a\nb\nc")
    let numbered = MarkdownFormat.apply(.numberedList, to: "a\n\nb", selection: NSRange(location: 0, length: 4))
    XCTAssertEqual(numbered.text, "1. a\n\n2. b")
  }

  func testListMarkerReplacesAnotherKind() {
    let edit = MarkdownFormat.apply(.bulletList, to: "- [ ] x", selection: NSRange(location: 7, length: 0))
    XCTAssertEqual(edit.text, "- x")
    XCTAssertEqual(edit.selection, NSRange(location: 3, length: 0))
  }

  func testMoveListItemDownSwapsNeighbors() {
    let text = "- one\n- two\n- three"
    let fromStart = MarkdownFormat.moveListItem(in: text, at: 0, by: 1)
    XCTAssertEqual(fromStart?.text, "- two\n- one\n- three")
    XCTAssertEqual(fromStart?.selection, NSRange(location: 6, length: 0), "the caret follows the moved item")
    let fromMiddle = MarkdownFormat.moveListItem(in: text, at: 3, by: 1)
    XCTAssertEqual(fromMiddle?.text, "- two\n- one\n- three")
    let secondDown = MarkdownFormat.moveListItem(in: text, at: 8, by: 1)
    XCTAssertEqual(secondDown?.text, "- one\n- three\n- two")
  }

  func testMoveListItemStopsAtTheListEdge() {
    XCTAssertNil(MarkdownFormat.moveListItem(in: "- only", at: 0, by: -1))
    XCTAssertNil(MarkdownFormat.moveListItem(in: "plain", at: 0, by: 1))
  }

  func testLinkWrapsTheSelection() {
    let edit = MarkdownFormat.apply(.link, to: "Photon", selection: NSRange(location: 0, length: 6))
    XCTAssertEqual(edit.text, "[Photon](url)")
  }

  func testChangeCoversOnlyTheEditedSpan() {
    let old = "line one\nhello world\nline three"
    let bold = MarkdownFormat.apply(.bold, to: old, selection: NSRange(location: 9, length: 5)).change(from: old)
    XCTAssertEqual(bold.range, NSRange(location: 9, length: 5))
    XCTAssertEqual(bold.replacement, "**hello**")
    // 😀 and 😃 share their UTF-16 lead surrogate, so the change must take the whole scalar.
    let emoji = MarkdownEdit(text: "- 😃 b", selection: NSRange()).change(from: "- 😀 b")
    XCTAssertEqual(emoji.range, NSRange(location: 2, length: 2))
    XCTAssertEqual(emoji.replacement, "😃")
  }
}

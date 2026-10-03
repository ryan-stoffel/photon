import Foundation

/// Inline and block markdown edits used by the notes format toolbar and ⌘K actions.
public enum MarkdownFormatStyle: Equatable, Sendable {
  case heading(Int)
  case bold
  case italic
  case strikethrough
  case underline
  case inlineCode
  case link
  case codeBlock
  case quote
  case bulletList
  case numberedList
  case checklist
}

public struct MarkdownEdit: Equatable, Sendable {
  public let text: String
  public let selection: NSRange

  public init(text: String, selection: NSRange) {
    self.text = text
    self.selection = selection
  }
}

public enum MarkdownFormat {
  /// Applies `style` to `selection` (UTF-16) in `text`. Empty selections insert markers
  /// and place the caret between them, or retarget the current line for block styles.
  /// Applying a style that is already there removes it, except for links and code blocks.
  public static func apply(_ style: MarkdownFormatStyle, to text: String, selection: NSRange) -> MarkdownEdit {
    let source = text as NSString
    let safe = clamped(selection, in: source)
    if let markers = wrapMarkers(for: style) {
      return wrap(source, selection: safe, left: markers.left, right: markers.right)
    }
    return applyBlock(style, in: source, selection: safe)
  }

  private static func wrapMarkers(for style: MarkdownFormatStyle) -> (left: String, right: String)? {
    switch style {
    case .bold:
      ("**", "**")
    case .italic:
      ("*", "*")
    case .strikethrough:
      ("~~", "~~")
    case .underline:
      ("<u>", "</u>")
    case .inlineCode:
      ("`", "`")
    default:
      nil
    }
  }

  private static func applyBlock(
    _ style: MarkdownFormatStyle,
    in source: NSString,
    selection: NSRange
  ) -> MarkdownEdit {
    switch style {
    case let .heading(level):
      applyHeading(level: max(1, min(level, 6)), in: source, selection: selection)
    case .link:
      applyLink(in: source, selection: selection)
    case .codeBlock:
      applyCodeBlock(in: source, selection: selection)
    case .quote, .bulletList, .numberedList, .checklist:
      toggleLineMarkers(style, in: source, selection: selection)
    default:
      MarkdownEdit(text: source as String, selection: selection)
    }
  }

  /// Swaps the list item containing `location` with the previous (`delta < 0`) or next item.
  public static func moveListItem(in text: String, at location: Int, by delta: Int) -> MarkdownEdit? {
    let source = text as NSString
    guard delta != 0, source.length > 0 else {
      return nil
    }
    let index = min(max(location, 0), source.length)
    let current = lineRange(at: index, in: source)
    guard isListItem(source.substring(with: current)) else {
      return nil
    }
    let neighbor: NSRange
    if delta < 0 {
      guard current.location > 0 else {
        return nil
      }
      neighbor = lineRange(at: current.location - 1, in: source)
    } else {
      let nextStart = lineEnd(of: current, in: source)
      guard nextStart < source.length else {
        return nil
      }
      neighbor = lineRange(at: nextStart, in: source)
    }
    guard isListItem(source.substring(with: neighbor)) else {
      return nil
    }
    let first = current.location < neighbor.location ? current : neighbor
    let second = current.location < neighbor.location ? neighbor : current
    let firstText = source.substring(with: first)
    let secondText = source.substring(with: second)
    let combined = NSMutableString(string: text)
    combined.replaceCharacters(in: second, with: firstText)
    combined.replaceCharacters(in: first, with: secondText)
    // Keep the caret on the moved item at the same column, so repeated presses keep moving it.
    let column = index - current.location
    let separator = second.location - first.upperBound
    let movedStart = delta < 0 ? first.location : first.location + (secondText as NSString).length + separator
    return MarkdownEdit(text: combined as String, selection: NSRange(location: movedStart + column, length: 0))
  }

  /// Wraps the selection in `left`/`right`, or removes them when they already sit just outside or at
  /// the edges of the selection.
  private static func wrap(_ source: NSString, selection: NSRange, left: String, right: String) -> MarkdownEdit {
    let leftLength = (left as NSString).length
    let markers = leftLength + (right as NSString).length
    let outer = NSRange(location: selection.location - leftLength, length: selection.length + markers)
    if outer.location >= 0, outer.upperBound <= source.length, isWrapped(outer, in: source, left: left, right: right) {
      let result = source.replacingCharacters(in: outer, with: source.substring(with: selection))
      return MarkdownEdit(text: result, selection: NSRange(location: outer.location, length: selection.length))
    }
    if selection.length > markers, isWrapped(selection, in: source, left: left, right: right) {
      let inner = NSRange(location: selection.location + leftLength, length: selection.length - markers)
      let result = source.replacingCharacters(in: selection, with: source.substring(with: inner))
      return MarkdownEdit(text: result, selection: NSRange(location: selection.location, length: inner.length))
    }
    if selection.length > 0 {
      let inner = source.substring(with: selection)
      let replacement = left + inner + right
      let result = source.replacingCharacters(in: selection, with: replacement)
      let location = selection.location + (left as NSString).length
      let innerLength = (inner as NSString).length
      return MarkdownEdit(text: result, selection: NSRange(location: location, length: innerLength))
    }
    let result = source.replacingCharacters(in: selection, with: left + right)
    return MarkdownEdit(
      text: result,
      selection: NSRange(location: selection.location + (left as NSString).length, length: 0)
    )
  }

  private static func applyLink(in source: NSString, selection: NSRange) -> MarkdownEdit {
    let inner = selection.length > 0 ? source.substring(with: selection) : "title"
    let replacement = "[\(inner)](url)"
    let result = source.replacingCharacters(in: selection, with: replacement)
    let urlStart = selection.location + (inner as NSString).length + 3
    return MarkdownEdit(text: result, selection: NSRange(location: urlStart, length: 3))
  }

  /// Whether `range` starts with `left` and ends with `right`. A `*` marker must not touch another `*`,
  /// so italic never takes one star of a `**bold**` marker.
  private static func isWrapped(_ range: NSRange, in source: NSString, left: String, right: String) -> Bool {
    let text = source.substring(with: range)
    guard text.hasPrefix(left), text.hasSuffix(right) else {
      return false
    }
    guard left == "*" else {
      return true
    }
    var neighbors = [range.location - 1, range.upperBound]
    if range.length > 2 {
      neighbors += [range.location + 1, range.upperBound - 2]
    }
    return !neighbors.contains { index in
      index >= 0 && index < source.length && source.substring(with: NSRange(location: index, length: 1)) == "*"
    }
  }

  /// Sets the caret line's heading level, or removes the heading when it already has that level.
  private static func applyHeading(level: Int, in source: NSString, selection: NSRange) -> MarkdownEdit {
    let line = lineRange(at: selection.location, in: source)
    let content = source.substring(with: line)
    let marker = content.range(of: "^#{1,6}(?:[ \\t]+|$)", options: .regularExpression)
    let currentLevel = marker.map { content[$0].count { $0 == "#" } }
    let body = marker.map { String(content[$0.upperBound...]) } ?? content
    let replacement = currentLevel == level ? body : String(repeating: "#", count: level) + " " + body
    let result = source.replacingCharacters(in: line, with: replacement)
    let caret = line.location + (replacement as NSString).length
    return MarkdownEdit(text: result, selection: NSRange(location: caret, length: 0))
  }

  /// Wraps the selected lines, or the caret's line, in a ``` fence and keeps the selection on the same text.
  private static func applyCodeBlock(in source: NSString, selection: NSRange) -> MarkdownEdit {
    let lines = lineRange(covering: selection, in: source)
    let fence = "```\n"
    let replacement = fence + source.substring(with: lines) + "\n```"
    let result = source.replacingCharacters(in: lines, with: replacement)
    let shifted = selection.location + (fence as NSString).length
    return MarkdownEdit(text: result, selection: NSRange(location: shifted, length: selection.length))
  }

  /// Puts `style`'s marker on every selected line, replacing any other list or quote marker. When every
  /// non-blank line already has that kind of marker, removes it instead. Numbered lines count up from 1.
  private static func toggleLineMarkers(
    _ style: MarkdownFormatStyle,
    in source: NSString,
    selection: NSRange
  ) -> MarkdownEdit {
    let block = lineRange(covering: selection, in: source)
    let lines = source.substring(with: block).components(separatedBy: "\n").map(MarkedLine.init)
    let filled = lines.filter { !$0.isBlank }
    let removing = !filled.isEmpty && filled.allSatisfy { $0.style == style }
    var number = 0
    let replacement = lines.map { line in
      if removing {
        return line.indent + line.body
      }
      if line.isBlank, lines.count > 1 {
        return line.text
      }
      number += 1
      return line.indent + marker(for: style, number: number) + line.body
    }.joined(separator: "\n")
    let result = source.replacingCharacters(in: block, with: replacement)
    let length = (replacement as NSString).length
    if selection.length > 0 {
      return MarkdownEdit(text: result, selection: NSRange(location: block.location, length: length))
    }
    let caret = max(block.location, selection.location + length - block.length)
    return MarkdownEdit(text: result, selection: NSRange(location: caret, length: 0))
  }

  private static func marker(for style: MarkdownFormatStyle, number: Int) -> String {
    switch style {
    case .quote:
      "> "
    case .numberedList:
      "\(number). "
    case .checklist:
      "- [ ] "
    default:
      "- "
    }
  }

  /// Leading indent, then an optional list or quote marker. Checklists come first so `- [ ] ` is not a bullet.
  private static let lineMarker = Pattern("^([ \\t]*)([-*+] \\[[ xX]\\] |\\d{1,9}[.)] |[-*+] |> )?")

  /// One line split into its indent, its list or quote marker, and the rest.
  private struct MarkedLine {
    let text: String
    let indent: String
    let style: MarkdownFormatStyle?
    let body: String

    var isBlank: Bool {
      text.allSatisfy(\.isWhitespace)
    }

    init(_ text: String) {
      let source = Source(text)
      let match = MarkdownFormat.lineMarker.firstMatch(in: source, range: NSRange(location: 0, length: source.length))
      let indentRange = match?.range(at: 1) ?? NSRange(location: 0, length: 0)
      let markerRange = match?.range(at: 2) ?? NSRange(location: NSNotFound, length: 0)
      let marker = markerRange.location == NSNotFound ? "" : source.substring(markerRange)
      self.text = text
      indent = source.substring(indentRange)
      body = source.nsString.substring(from: indentRange.upperBound + (marker as NSString).length)
      if marker.isEmpty {
        style = nil
      } else if marker.hasPrefix(">") {
        style = .quote
      } else if marker.contains("[") {
        style = .checklist
      } else {
        style = marker.first?.isNumber == true ? .numberedList : .bulletList
      }
    }
  }

  private static func lineRange(at location: Int, in source: NSString) -> NSRange {
    lineRange(covering: NSRange(location: min(location, source.length), length: 0), in: source)
  }

  /// Every line `range` touches, without the last line's terminator.
  private static func lineRange(covering range: NSRange, in source: NSString) -> NSRange {
    var start = 0
    var end = 0
    var contentsEnd = 0
    source.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: range)
    return NSRange(location: start, length: contentsEnd - start)
  }

  /// Index just past this line's terminator, which is where the next line starts.
  private static func lineEnd(of range: NSRange, in source: NSString) -> Int {
    var start = 0
    var end = 0
    var contentsEnd = 0
    source.getLineStart(&start, end: &end, contentsEnd: &contentsEnd, for: range)
    return end
  }

  private static func isListItem(_ line: String) -> Bool {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
      return true
    }
    guard let dot = trimmed.firstIndex(where: { $0 == "." || $0 == ")" }) else {
      return false
    }
    let number = trimmed[..<dot]
    return !number.isEmpty && number.allSatisfy(\.isNumber)
  }

  private static func clamped(_ range: NSRange, in source: NSString) -> NSRange {
    let location = min(max(range.location, 0), source.length)
    let length = min(max(range.length, 0), source.length - location)
    return NSRange(location: location, length: length)
  }
}

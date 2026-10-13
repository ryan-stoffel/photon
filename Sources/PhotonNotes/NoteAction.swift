import Foundation
import PhotonCore

/// One row in the notes ⌘K actions palette.
public struct NoteAction: Identifiable, Equatable, Sendable {
  public enum Kind: String, CaseIterable, Sendable {
    case newNote
    case duplicateNote
    case browseNotes
    case findInNote
    case copyNote
    case copyDeepLink
    case exportNote
    case moveListItemUp
    case moveListItemDown
    case format
    case zoomIn
    case zoomOut
    case resetZoom
    case deleteNote
  }

  public let id: Kind
  public let title: String
  public let symbolName: String
  public let shortcut: String
  public let keywords: [String]

  public static let catalog: [NoteAction] = [
    NoteAction(
      id: .newNote,
      title: "New Note",
      symbolName: "plus",
      shortcut: "⌘N",
      keywords: ["new", "create"]
    ),
    NoteAction(
      id: .duplicateNote,
      title: "Duplicate Note",
      symbolName: "plus.square.on.square",
      shortcut: "⌘D",
      keywords: ["duplicate", "copy"]
    ),
    NoteAction(
      id: .browseNotes,
      title: "Browse Notes",
      symbolName: "list.bullet.rectangle",
      shortcut: "⌘P",
      keywords: ["browse", "switch", "list"]
    ),
    NoteAction(
      id: .findInNote,
      title: "Find in Note",
      symbolName: "magnifyingglass",
      shortcut: "⌘F",
      keywords: ["find", "search"]
    ),
    NoteAction(
      id: .copyNote,
      title: "Copy Note",
      symbolName: "doc.on.doc",
      shortcut: "⇧⌘C",
      keywords: ["copy", "clipboard"]
    ),
    NoteAction(
      id: .copyDeepLink,
      title: "Copy Deeplink",
      symbolName: "link",
      shortcut: "⇧⌘D",
      keywords: ["link", "deeplink", "url"]
    ),
    NoteAction(
      id: .exportNote,
      title: "Export…",
      symbolName: "square.and.arrow.up",
      shortcut: "⇧⌘E",
      keywords: ["export", "save", "share"]
    ),
    NoteAction(
      id: .moveListItemUp,
      title: "Move List Item Up",
      symbolName: "arrow.up",
      shortcut: "⌥⌘↑",
      keywords: ["move", "list", "up"]
    ),
    NoteAction(
      id: .moveListItemDown,
      title: "Move List Item Down",
      symbolName: "arrow.down",
      shortcut: "⌥⌘↓",
      keywords: ["move", "list", "down"]
    ),
    NoteAction(
      id: .format,
      title: "Format…",
      symbolName: "textformat",
      shortcut: "⌥⌘,",
      keywords: ["format", "bold", "heading"]
    ),
    NoteAction(
      id: .zoomIn,
      title: "Zoom In",
      symbolName: "plus.magnifyingglass",
      shortcut: "⌘=",
      keywords: ["zoom", "larger", "text size"]
    ),
    NoteAction(
      id: .zoomOut,
      title: "Zoom Out",
      symbolName: "minus.magnifyingglass",
      shortcut: "⌘-",
      keywords: ["zoom", "smaller", "text size"]
    ),
    NoteAction(
      id: .resetZoom,
      title: "Reset Zoom",
      symbolName: "1.magnifyingglass",
      shortcut: "⌘0",
      keywords: ["zoom", "reset", "text size"]
    ),
    NoteAction(
      id: .deleteNote,
      title: "Delete Note",
      symbolName: "trash",
      shortcut: "⌃X",
      keywords: ["delete", "remove", "trash"]
    ),
  ]

  public static func matching(_ query: String) -> [NoteAction] {
    let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
    if needle.isEmpty {
      return catalog
    }
    return catalog.filter { action in
      FuzzyMatcher.matches(query: needle, candidate: action.title)
        || action.keywords.contains { FuzzyMatcher.matches(query: needle, candidate: $0) }
    }
  }
}

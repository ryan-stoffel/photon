import Foundation
import PhotonCore

/// Launcher integration: "Notes", "Create Note", "Search Notes", and one result per note for `notes` /
/// `n <title>` queries.
///
/// Unchecked because the only stored reference is the main-actor-isolated controller.
public final class NotesProvider: CommandProvider, @unchecked Sendable {
  public static let openCommandID = "notes.open"
  public static let newCommandID = "notes.new"
  public static let searchCommandID = "notes.search"
  public static let noteCommandPrefix = "note:"

  public let id = "notes"
  public let displayName = "Notes"

  private let controller: NotesController

  public init(controller: NotesController) {
    self.controller = controller
  }

  public func reload() async {
    await controller.refreshFromDisk()
  }

  public func commands(matching query: String) async -> [Command] {
    var commands = [openCommand, newCommand, searchCommand]
    guard case let .list(filter) = NoteQuery.parse(query) else {
      return commands
    }
    let notes = await controller.noteSummaries()
    for note in notes where filter.isEmpty || FuzzyMatcher.matches(query: filter, candidate: note.title) {
      commands.append(command(for: note))
    }
    return commands
  }

  public func execute(_ command: Command) async throws {
    switch command.id {
    case Self.openCommandID:
      await controller.show()
    case Self.newCommandID:
      await controller.createNote()
    case Self.searchCommandID:
      await controller.presentSwitcher()
    default:
      guard command.id.hasPrefix(Self.noteCommandPrefix) else {
        throw NotesError.noteNotFound(command.id)
      }
      let noteID = String(command.id.dropFirst(Self.noteCommandPrefix.count))
      try await controller.open(noteID: noteID)
    }
  }

  private var openCommand: Command {
    Command(
      id: Self.openCommandID,
      title: "Notes",
      subtitle: "Notes",
      keywords: ["note", "notes", "n"],
      providerID: id,
      icon: .symbol(name: "note.text")
    )
  }

  private var newCommand: Command {
    Command(
      id: Self.newCommandID,
      title: "Create Note",
      subtitle: "Notes",
      keywords: ["note", "notes", "new note"],
      providerID: id,
      icon: .symbol(name: "square.and.pencil")
    )
  }

  private var searchCommand: Command {
    Command(
      id: Self.searchCommandID,
      title: "Search Notes",
      subtitle: "Notes",
      keywords: ["note", "notes", "browse notes"],
      providerID: id,
      icon: .symbol(name: "magnifyingglass")
    )
  }

  private func command(for note: NoteSummary) -> Command {
    Command(
      id: Self.noteCommandPrefix + note.id,
      title: note.title,
      subtitle: note.preview.isEmpty ? "Note" : note.preview,
      keywords: NoteQuery.keywords(forTitle: note.title),
      providerID: id,
      icon: .symbol(name: "doc.text")
    )
  }
}

import Foundation
import PhotonCore

public enum FilesProviderError: LocalizedError, Sendable {
  case unknownCommand(String)

  public var errorDescription: String? {
    switch self {
    case let .unknownCommand(id):
      "That file no longer exists (\(id))."
    }
  }
}

/// Launcher provider for the Files feature: the "Search Files" command plus
/// filename matches inline in the default results (no Files-mode prefix required).
///
/// Inline results never block the launcher. `commands(matching:)` returns what
/// is cached for the exact query and otherwise starts a debounced Spotlight
/// search in the background; when that finishes, `onInlineResultsChanged`
/// asks the launcher to refresh, the cache now matches, and the rows appear.
public final class FilesProvider: CommandProvider, @unchecked Sendable {
  public static let searchCommandID = "files:search"
  public static let fileCommandPrefix = "file:"

  /// Latest inline search, for the packaged-app harness.
  public struct InlineSnapshot: Equatable, Sendable {
    public var query: String
    public var count: Int
    public var settled: Bool

    public static let empty = InlineSnapshot(query: "", count: 0, settled: false)
  }

  public let id = "files"
  public let displayName = "Files"

  /// Invoked on the main actor when inline results for `query` (trimmed) are cached.
  /// The launcher re-runs its search so the rows appear in the root list.
  public var onInlineResultsChanged: (@MainActor (_ query: String) -> Void)?

  private struct InlineCache {
    let query: String
    let files: [FileResult]
  }

  private let lock = NSLock()
  private let engine: FileSearchEngine
  private var settings = FileSearchSettings()
  private var cache: InlineCache?
  private var inlinePendingQuery: String?
  private var inlineGeneration = 0

  @MainActor
  public init(engine: FileSearchEngine = FileSearchEngine()) {
    self.engine = engine
  }

  public var searchCommand: Command {
    Command(
      id: Self.searchCommandID,
      title: "Search Files",
      subtitle: "Find files and folders with Spotlight",
      keywords: ["files", "file", "find", "finder", "spotlight", "folder", "search"],
      providerID: id,
      icon: .symbol(name: "doc.text.magnifyingglass")
    )
  }

  public func update(settings: FileSearchSettings) {
    synchronized {
      self.settings = settings
      cache = nil
    }
  }

  public func commands(matching query: String) async -> [Command] {
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    var commands = [searchCommand]
    let (current, cached) = synchronized { (settings, cache) }

    guard current.inlineResults, trimmed.count >= FileSearchSettings.inlineMinimumQueryLength else {
      return commands
    }
    if let cached, cached.query == trimmed {
      commands += cached.files.map(command(for:))
      return commands
    }
    scheduleInlineSearch(query: trimmed, settings: current)
    return commands
  }

  public func execute(_ command: Command) async throws {
    if command.id == Self.searchCommandID {
      return
    }
    // Read the row's file from disk: the inline cache may have been cleared since it was shown.
    guard let path = Self.path(forCommandID: command.id), let file = FileResultFactory.file(at: path) else {
      throw FilesProviderError.unknownCommand(command.id)
    }
    let action = synchronized { settings.defaultAction }
    try await MainActor.run {
      try FileActions.perform(action, on: file)
    }
  }

  /// Path behind an inline file command, or `nil` for other commands.
  public static func path(forCommandID commandID: String) -> String? {
    guard commandID.hasPrefix(fileCommandPrefix) else {
      return nil
    }
    return String(commandID.dropFirst(fileCommandPrefix.count))
  }

  private func command(for file: FileResult) -> Command {
    Command(
      id: Self.fileCommandPrefix + file.path,
      title: file.displayName,
      subtitle: PathFormatter.parentDisplay(for: file.path, maxLength: 60),
      keywords: [file.fileName],
      providerID: id,
      icon: .fileIcon(path: file.path)
    )
  }

  private func scheduleInlineSearch(query: String, settings: FileSearchSettings) {
    let generation = synchronized { () -> Int in
      inlineGeneration += 1
      inlinePendingQuery = query
      return inlineGeneration
    }
    Task { @MainActor [weak self] in
      guard let self else {
        return
      }
      let request = FileSearchEngine.Request(
        query: query,
        settings: settings,
        limit: FileSearchSettings.inlineLimit,
        includeApplications: false
      )
      guard let response = await engine.search(request) else {
        return
      }
      guard generation == synchronized({ inlineGeneration }) else {
        return
      }
      let shown = Array(response.files.prefix(FileSearchSettings.inlineLimit))
      let cache = InlineCache(query: query, files: shown.map(\.file))
      synchronized {
        self.cache = cache
        if self.inlinePendingQuery == query {
          self.inlinePendingQuery = nil
        }
      }
      onInlineResultsChanged?(query)
    }
  }

  /// `settled` is true once the latest query has a cache entry and nothing newer is in flight.
  public func inlineSnapshot() -> InlineSnapshot {
    synchronized {
      InlineSnapshot(
        query: cache?.query ?? "",
        count: cache?.files.count ?? 0,
        settled: inlinePendingQuery == nil && cache != nil
      )
    }
  }

  /// Cancels in-flight inline Spotlight work so Files mode recents/search are not raced.
  @MainActor
  public func prepareForFullSession() {
    engine.cancel()
    synchronized {
      inlineGeneration += 1
      cache = nil
      inlinePendingQuery = nil
    }
  }

  private func synchronized<T>(_ body: () throws -> T) rethrows -> T {
    lock.lock()
    defer { lock.unlock() }
    return try body()
  }
}

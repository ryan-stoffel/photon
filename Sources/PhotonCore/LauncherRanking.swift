import Foundation

/// Orders the empty-query Suggestions section by how often each application or command is opened.
public enum LauncherRanking {
  /// Count-sorted prefix. Never-opened rows stay in the catalog after this prefix.
  public static let suggestionLimit = LauncherLayout.recommendationCatalogLimit

  public struct Usage: Equatable, Sendable {
    public var count: Int
    public var lastUsed: Date

    public init(count: Int, lastUsed: Date) {
      self.count = count
      self.lastUsed = lastUsed
    }
  }

  /// Applications and launcher commands that have actually been opened, highest local use count first.
  /// File hits, individual notes, calculator results, and Settings panes stay out even when their counts
  /// are higher. Ties break toward the more recent open, then title.
  public static func suggestions(
    from ranked: [RankedCommand],
    usage: [String: Usage],
    limit: Int = suggestionLimit
  ) -> [RankedCommand] {
    let capped = max(limit, 0)
    guard capped > 0 else {
      return []
    }
    var seen = Set<String>()
    let candidates = ranked.filter { command in
      guard includesInSuggestions(command.command) else {
        return false
      }
      guard let record = usageRecord(command.id, usage: usage) else {
        return false
      }
      let opens = record.count
      guard opens > 0 else {
        return false
      }
      return seen.insert(command.id).inserted
    }
    let sorted = candidates.sorted { lhs, rhs in
      let left = usageRecord(lhs.id, usage: usage)
      let right = usageRecord(rhs.id, usage: usage)
      let leftCount = left?.count ?? 0
      let rightCount = right?.count ?? 0
      if leftCount != rightCount {
        return leftCount > rightCount
      }
      let leftUsed = left?.lastUsed ?? .distantPast
      let rightUsed = right?.lastUsed ?? .distantPast
      if leftUsed != rightUsed {
        return leftUsed > rightUsed
      }
      return lhs.command.title.localizedCaseInsensitiveCompare(rhs.command.title) == .orderedAscending
    }
    return Array(sorted.prefix(capped))
  }

  /// When a typed query matches an application, that app stays ahead of the
  /// file-search action and filename hits. Order inside each group is unchanged.
  /// Callers skip this for the empty-query catalog so Suggestions stay ordered by use count.
  public static func applicationsBeforeFileHits(
    _ ranked: [RankedCommand],
    filesProviderID: String = "files"
  ) -> [RankedCommand] {
    let hasApplication = ranked.contains {
      LauncherRow(command: $0.command).applicationBundleIdentifier != nil
    }
    guard hasApplication else {
      return ranked
    }
    var leading: [RankedCommand] = []
    var files: [RankedCommand] = []
    leading.reserveCapacity(ranked.count)
    for item in ranked {
      if item.command.providerID == filesProviderID {
        files.append(item)
      } else {
        leading.append(item)
      }
    }
    return leading + files
  }

  /// Real applications, plus standing commands such as Clipboard History, Search Files, Notes, and window
  /// layouts. File hits, individual notes, and Settings panes are catalog rows, not Suggestions.
  static func includesInSuggestions(_ command: Command) -> Bool {
    if LauncherRow(command: command).applicationBundleIdentifier != nil {
      return true
    }
    switch command.providerID {
    case "clipboard", "files", "notes", "keybinds":
      return !command.id.hasPrefix("file:") && !command.id.hasPrefix("note:")
    default:
      return false
    }
  }

  private static func usageRecord(_ id: String, usage: [String: Usage]) -> Usage? {
    if let record = usage[id] {
      return record
    }
    return usage.first { $0.key.caseInsensitiveCompare(id) == .orderedSame }?.value
  }
}

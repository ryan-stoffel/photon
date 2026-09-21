import Foundation

/// Orders the empty-query Suggestions section by how often each application is opened.
public enum LauncherRanking {
  /// Most-used apps shown under Suggestions. Files, notes, and commands are not included.
  public static let suggestionLimit = 6

  public struct Usage: Equatable, Sendable {
    public var count: Int
    public var lastUsed: Date

    public init(count: Int, lastUsed: Date) {
      self.count = count
      self.lastUsed = lastUsed
    }
  }

  /// Applications Ryan has actually opened, highest local use count first.
  /// Panes, files, notes, and commands are left out even when their counts are higher.
  /// Ties break toward the more recent open, then title.
  public static func suggestedApps(
    from ranked: [RankedCommand],
    usage: [String: Usage],
    limit: Int = suggestionLimit
  ) -> [RankedCommand] {
    let capped = max(limit, 0)
    guard capped > 0 else {
      return []
    }
    var seen = Set<String>()
    let apps = ranked.filter { command in
      guard LauncherRow(command: command.command).applicationBundleIdentifier != nil else {
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
    let sorted = apps.sorted { lhs, rhs in
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

  private static func usageRecord(_ id: String, usage: [String: Usage]) -> Usage? {
    if let record = usage[id] {
      return record
    }
    return usage.first { $0.key.caseInsensitiveCompare(id) == .orderedSame }?.value
  }
}

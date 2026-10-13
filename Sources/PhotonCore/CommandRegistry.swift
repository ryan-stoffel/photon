import Foundation

/// Holds the active providers and fans search / execute out to them.
public final class CommandRegistry: @unchecked Sendable {
  private let lock = NSLock()
  private var providers: [any CommandProvider] = []

  public init() {}

  public func register(_ provider: any CommandProvider) {
    lock.lock()
    defer { lock.unlock() }
    if let index = providers.firstIndex(where: { $0.id == provider.id }) {
      providers[index] = provider
    } else {
      providers.append(provider)
    }
  }

  public func provider(id: String) -> (any CommandProvider)? {
    lock.lock()
    defer { lock.unlock() }
    return providers.first { $0.id == id }
  }

  public var allProviders: [any CommandProvider] {
    lock.lock()
    defer { lock.unlock() }
    return providers
  }

  public func reloadAll() async {
    let snapshot = allProviders
    for provider in snapshot {
      await provider.reload()
    }
  }

  /// Ranks every provider's matches for `query`. A typed query orders by text match, and frecency
  /// (capped at 0.2) only breaks near-ties. The empty query orders by raw frecency.
  public func search(_ query: String, frecency: FrecencyStore) async -> [RankedCommand] {
    let snapshot = allProviders
    let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
    var ranked: [RankedCommand] = []
    ranked.reserveCapacity(64)

    for provider in snapshot {
      let commands = await provider.commands(matching: query)
      for command in commands {
        let text = textScore(query: trimmed, command: command)
        if text == nil, !trimmed.isEmpty {
          continue
        }
        let freq = frecency.score(id: command.id)
        let boost = trimmed.isEmpty ? freq : min(freq, 2) * 0.1
        ranked.append(
          RankedCommand(command: command, textScore: text ?? 0, frecencyScore: boost)
        )
      }
    }

    return ranked.sorted { lhs, rhs in
      if lhs.combinedScore != rhs.combinedScore {
        return lhs.combinedScore > rhs.combinedScore
      }
      return lhs.command.title.localizedCaseInsensitiveCompare(rhs.command.title) == .orderedAscending
    }
  }

  public func execute(_ command: Command) async throws {
    guard let provider = provider(id: command.providerID) else {
      throw CommandRegistryError.unknownProvider(command.providerID)
    }
    try await provider.execute(command)
  }

  /// Exact title 6, exact keyword 5, fuzzy title (0, 1], fuzzy keyword 0.15, otherwise no match.
  private func textScore(query: String, command: Command) -> Double? {
    if query.isEmpty {
      return 0
    }
    if command.title.caseInsensitiveCompare(query) == .orderedSame {
      return 6
    }
    if command.keywords.contains(where: { $0.caseInsensitiveCompare(query) == .orderedSame }) {
      return 5
    }
    if let score = FuzzyMatcher.score(query: query, candidate: command.title) {
      return score
    }
    if command.keywords.contains(where: { FuzzyMatcher.score(query: query, candidate: $0) != nil }) {
      return 0.15
    }
    return nil
  }
}

public enum CommandRegistryError: Error, Sendable, Equatable {
  case unknownProvider(String)
}

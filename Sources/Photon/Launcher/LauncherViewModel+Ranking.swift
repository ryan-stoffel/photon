import PhotonCore

struct LauncherArrangement {
  var commands: [RankedCommand]
  var suggestionCount: Int
}

extension LauncherViewModel {
  /// Primary results first; a mode's inline results (never its activation command) trail them
  /// except files, which mix into the main list so a query like `ember` shows Documents
  /// hits without typing "files" first.
  /// An empty query leads with Suggestions: applications ranked by local open count.
  func arrange(_ ranked: [RankedCommand], forEmptyQuery isSuggestions: Bool) -> LauncherArrangement {
    var primary: [RankedCommand] = []
    var trailing: [RankedCommand] = []
    for item in ranked {
      let mode = mode(forInlineProvider: item.command.providerID)
      if let mode, item.command.id != mode.activationCommandID, mode.id != "files" {
        trailing.append(item)
      } else {
        primary.append(item)
      }
    }
    if isSuggestions {
      return suggestionsArrangement(primary)
    }
    let commands = Array(primary.prefix(limit)) + Array(trailing.prefix(trailingLimit))
    return LauncherArrangement(commands: commands, suggestionCount: 0)
  }

  private func suggestionsArrangement(_ primary: [RankedCommand]) -> LauncherArrangement {
    let usage = frecency.records.mapValues {
      LauncherRanking.Usage(count: $0.count, lastUsed: $0.lastUsed)
    }
    let suggestions = LauncherRanking.suggestedApps(from: primary, usage: usage)
    var seen = Set(suggestions.map(\.id))
    var rest: [RankedCommand] = []
    rest.reserveCapacity(LauncherLayout.recommendationCatalogLimit)
    for item in primary where seen.insert(item.id).inserted {
      rest.append(item)
      if suggestions.count + rest.count == LauncherLayout.recommendationCatalogLimit {
        break
      }
    }
    return LauncherArrangement(commands: suggestions + rest, suggestionCount: suggestions.count)
  }
}

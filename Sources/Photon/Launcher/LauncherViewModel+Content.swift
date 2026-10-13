import PhotonCore

extension LauncherViewModel {
  /// Panel content for the command session: a mode's layout, the compact bar, Suggestions, or result rows.
  func commandsContent() -> LauncherContent {
    if let activeMode {
      return activeMode.prefersCompactLauncherLayout ? .searchOnly : .fullHeight
    }
    if query.isEmpty {
      return preferences.showsSuggestions || revealsRecommendations ? .recommendations : .searchOnly
    }
    if results.isEmpty, query != resultsQuery {
      // The first search for this query is still running. Keep the height instead of
      // flashing an empty row before the results land.
      return content
    }
    return .rows(count: results.count, showsCalculatorHero: calculatorHero != nil)
  }

  /// Clipboard history always opens expanded. A filter with no matches keeps the height. History that
  /// is off shows one message line, sized like the zero-result list (no section header).
  func clipboardContent() -> LauncherContent {
    guard let clipboard else {
      return .searchOnly
    }
    if !clipboard.manager.items.isEmpty {
      return .fullHeight
    }
    if clipboard.showsCompactEmptyRow {
      return .rows(count: 0, showsCalculatorHero: false)
    }
    return .searchOnly
  }
}

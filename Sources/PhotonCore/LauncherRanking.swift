/// Orders launcher results so currently open applications sit above everything else.
public enum LauncherRanking {
  /// Running `app:` rows keep their relative order and move to the front.
  /// Files, notes, panes, and commands stay put unless they are applications.
  public static func promotingRunningApps(
    _ ranked: [RankedCommand],
    runningBundleIDs: Set<String>
  ) -> [RankedCommand] {
    var running: [RankedCommand] = []
    var rest: [RankedCommand] = []
    running.reserveCapacity(ranked.count)
    rest.reserveCapacity(ranked.count)
    for item in ranked {
      if LauncherRow(command: item.command).showsRunningIndicator(runningBundleIDs: runningBundleIDs) {
        running.append(item)
      } else {
        rest.append(item)
      }
    }
    return running + rest
  }
}

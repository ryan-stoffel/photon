import Foundation
import PhotonCore

/// Debounced, cancellable Spotlight search via `mdfind`. One engine serves one
/// consumer: each new `search` supersedes the previous one, so stale results
/// are never delivered and the panel never flickers between old and new lists.
@MainActor
public final class FileSearchEngine {
  public struct Request: Equatable, Sendable {
    public var query: String
    public var settings: FileSearchSettings
    public var limit: Int
    public var includeApplications: Bool

    public init(query: String, settings: FileSearchSettings, limit: Int, includeApplications: Bool = true) {
      self.query = query
      self.settings = settings
      self.limit = limit
      self.includeApplications = includeApplications
    }
  }

  public struct Response: Sendable {
    public let query: String
    public let files: [RankedFile]
    public let spotlightAvailable: Bool
  }

  public static let defaultDebounce: Duration = .milliseconds(120)
  /// `mdfind` on a short substring can scan the whole home folder; expire it so
  /// Files never sits on a stuck Searching panel.
  public static let queryTimeout: Duration = .milliseconds(1800)

  private let debounce: Duration
  private var generation = 0
  private var runners: [MdfindQueryRunner] = []

  public init(debounce: Duration = FileSearchEngine.defaultDebounce) {
    self.debounce = debounce
  }

  /// Waits out the debounce window, cancels any in-flight query, runs
  /// `mdfind` (the metadata query plus one filename query per term) and a
  /// bounded filesystem fallback, then ranks off the main thread.
  /// Returns `nil` when a newer search superseded this one, in which case the
  /// caller should do nothing.
  public func search(_ request: Request) async -> Response? {
    generation += 1
    let token = generation
    cancelRunners()

    let trimmed = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let queryString = SpotlightQueryBuilder.queryString(
      for: trimmed,
      searchContents: request.settings.searchContents
    ) else {
      return Response(query: trimmed, files: [], spotlightAvailable: true)
    }
    if let response = nativeParityResponse(for: request, query: trimmed) {
      return response
    }

    if debounce > .zero {
      try? await Task.sleep(for: debounce)
    }
    guard token == generation, !Task.isCancelled else {
      return nil
    }

    let started = PhotonTiming.start()
    let response = await runQuery(
      request: request,
      queryString: queryString,
      trimmed: trimmed,
      token: token
    )
    PhotonTiming.end("files.search", from: started)
    return response
  }

  private func runQuery(
    request: Request,
    queryString: String,
    trimmed: String,
    token: Int
  ) async -> Response? {
    let folders = onlyInFolders(for: request.settings)
    let scanLimit = max(500, request.limit * 20)
    let terms = SpotlightQueryBuilder.terms(from: trimmed)
    var invocations: [MdfindQueryRunner.Request] = [
      MdfindQueryRunner.Request(queryString: queryString, onlyIn: folders, scanLimit: scanLimit)
    ]
    for term in terms {
      invocations.append(
        MdfindQueryRunner.Request(
          queryString: SpotlightQueryBuilder.fileNameQueryString(for: term),
          onlyIn: folders,
          scanLimit: scanLimit
        )
      )
    }

    let home = NSHomeDirectory()
    let fallbackRoots = FileSearchFallbackRoots.roots(for: request.settings, home: home)
    FileSearchDebugLog.log(
      "search '\(trimmed)' mdfind=\(folders.count) fallbackRoots=\(fallbackRoots.count)"
    )
    let fallbackTask = Task.detached(priority: .userInitiated) {
      FileSystemFallbackSearch.paths(
        matching: trimmed,
        roots: fallbackRoots,
        home: home,
        resultLimit: scanLimit
      )
    }
    let outcomes = await withTaskGroup(of: (Int, MdfindQueryRunner.Outcome).self) { group in
      for (index, invocation) in invocations.enumerated() {
        group.addTask {
          await (index, self.runMdfind(invocation))
        }
      }
      var collected: [(Int, MdfindQueryRunner.Outcome)] = []
      for await outcome in group {
        collected.append(outcome)
      }
      return collected.sorted { $0.0 < $1.0 }.map(\.1)
    }
    guard token == generation, !Task.isCancelled else {
      fallbackTask.cancel()
      return nil
    }

    let fallbackPaths = await fallbackTask.value
    guard token == generation, !Task.isCancelled else {
      return nil
    }
    let completedOutcomes = outcomes.filter { !$0.cancelled }
    let spotlightAvailable = completedOutcomes.allSatisfy(\.spotlightAvailable)
    let uniquePaths = uniqued(completedOutcomes.flatMap(\.paths) + fallbackPaths)
    // Only the metadata query (invocation 0) can match file text.
    let contentMatches: Set<String> = request.settings.searchContents
      ? Set(outcomes[0].paths.map(PathFormatter.resolvingFirmlink))
      : []
    let ranked = await Task.detached(priority: .userInitiated) {
      let files = uniquePaths.compactMap(FileResultFactory.file(at:))
      let ranked = FileRanker.rank(
        files,
        query: trimmed,
        excludedFolders: request.settings.excludedFolders,
        includeApplications: request.includeApplications,
        limit: request.limit,
        scope: request.settings.scope,
        extraFolders: request.settings.extraFolders + request.settings.grantedFolders,
        contentMatches: contentMatches
      )
      FileIconCache.shared.prefetch(ranked.map(\.file))
      return ranked
    }.value
    guard token == generation else {
      return nil
    }
    return Response(query: trimmed, files: ranked, spotlightAvailable: spotlightAvailable)
  }

  /// Loads recent documents for the empty Files view: files used in the last
  /// 30 days, newest Spotlight last-used date first. Runtime fixtures may add
  /// explicit paths for the packaged-app visual gate.
  public func recent(settings: FileSearchSettings, limit: Int) async -> Response? {
    generation += 1
    let token = generation
    cancelRunners()
    let request = MdfindQueryRunner.Request(
      queryString: "kMDItemLastUsedDate >= $time.today(-30) && kMDItemContentTypeTree = 'public.content' && "
        + SpotlightQueryBuilder.systemFileExclusion,
      onlyIn: onlyInFolders(for: settings),
      scanLimit: max(300, limit * 10)
    )
    let outcome = await runMdfind(request)
    guard token == generation, !Task.isCancelled else {
      return nil
    }
    let fixturePaths = ProcessInfo.processInfo.environment["PHOTON_NATIVE_PARITY_RECENT_FILES"]?
      .split(separator: ":")
      .map(String.init) ?? []
    let paths = uniqued(outcome.paths)
    let excludedFolders = settings.excludedFolders
    let recent = await Task.detached(priority: .userInitiated) {
      let fixtureFiles = fixturePaths.compactMap(FileResultFactory.file(at:))
      let fixtureSet = Set(fixtureFiles.map(\.path))
      let discoveredFiles = paths
        .compactMap(FileResultFactory.file(at:))
        .filter { file in
          !file.isApplication && !fixtureSet.contains(file.path)
            && !FileRanker.isExcluded(file.path, folders: excludedFolders)
        }
        .map { ($0, FileResultFactory.spotlightLastUsedDate(of: $0) ?? .distantPast) }
        .sorted { lhs, rhs in
          if lhs.1 != rhs.1 {
            return lhs.1 > rhs.1
          }
          return lhs.0.displayName.localizedCaseInsensitiveCompare(rhs.0.displayName) == .orderedAscending
        }
        .map(\.0)
      let files = Array((fixtureFiles + discoveredFiles).prefix(limit))
      FileIconCache.shared.prefetch(files)
      return files.enumerated().map { index, file in
        RankedFile(file: file, relevance: Double(limit - index))
      }
    }.value
    guard token == generation, !Task.isCancelled else {
      return nil
    }
    return Response(query: "", files: recent, spotlightAvailable: outcome.spotlightAvailable)
  }

  public func cancel() {
    generation += 1
    cancelRunners()
  }

  /// Home scope uses `mdfind -onlyin $HOME` (plus extra folders). Computer
  /// scope omits `-onlyin` so Spotlight searches this Mac.
  private func onlyInFolders(for settings: FileSearchSettings) -> [String] {
    var folders: [String] = []
    if settings.scope == .home {
      folders.append(NSHomeDirectory())
    }
    let extras = FileRanker.normalizedFolders(
      settings.extraFolders + settings.grantedFolders,
      home: NSHomeDirectory()
    )
    for folder in extras where folder.hasPrefix("/") && !folders.contains(folder) {
      folders.append(folder)
    }
    return folders
  }

  private func runMdfind(_ request: MdfindQueryRunner.Request) async -> MdfindQueryRunner.Outcome {
    let runner = MdfindQueryRunner()
    runners.append(runner)
    let timeout = FileSearchEngine.queryTimeout
    let outcome: MdfindQueryRunner.Outcome = await Task.detached(priority: .userInitiated) {
      await withCheckedContinuation { continuation in
        runner.start(request) { outcome in
          continuation.resume(returning: outcome)
        }
        Task {
          try? await Task.sleep(for: timeout)
          runner.expire()
        }
      }
    }.value
    runners.removeAll { $0 === runner }
    return outcome
  }

  private func cancelRunners() {
    for runner in runners {
      runner.cancel()
    }
    runners = []
  }

  private func uniqued(_ paths: [String]) -> [String] {
    var seen = Set<String>()
    return paths.filter { seen.insert($0).inserted }
  }

  private func nativeParityGrantedFixtures(settings: FileSearchSettings) -> [String] {
    let fixtures = ProcessInfo.processInfo.environment["PHOTON_NATIVE_PARITY_GRANTED_FILES"]?
      .split(separator: ":")
      .map(String.init) ?? []
    return fixtures.filter { fixture in
      settings.grantedFolders.contains { folder in
        fixture == folder || fixture.hasPrefix(folder + "/")
      }
    }
  }

  private func nativeParityResponse(for request: Request, query: String) -> Response? {
    let granted = nativeParityGrantedFixtures(settings: request.settings)
      .compactMap(FileResultFactory.file(at:))
    if !granted.isEmpty {
      let ranked = granted.prefix(request.limit).map {
        RankedFile(file: $0, relevance: 1)
      }
      return Response(query: query, files: ranked, spotlightAvailable: true)
    }
    let named = nativeParityNamedFiles(matching: query)
    guard !named.isEmpty else {
      return nil
    }
    let ranked = named.prefix(request.limit).map {
      RankedFile(file: $0, relevance: 1)
    }
    return Response(query: query, files: ranked, spotlightAvailable: true)
  }

  /// Filename fixtures that match this query. Used so the packaged harness can
  /// prove an app-name query keeps the application above a real file hit.
  private func nativeParityNamedFiles(matching query: String) -> [FileResult] {
    let paths = ProcessInfo.processInfo.environment["PHOTON_NATIVE_PARITY_NAMED_FILES"]?
      .split(separator: ":")
      .map(String.init) ?? []
    return paths.compactMap(FileResultFactory.file(at:)).filter { file in
      FileRanker.relevance(of: file, query: query) > 0
    }
  }
}

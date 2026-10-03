import AppKit
import PhotonCore
import SwiftUI

/// Results area of the launcher while it is in file mode. The launcher draws the footer
/// and its action bar below this view.
public struct FileSearchView: View {
  @ObservedObject private var controller: FileSearchController

  public init(controller: FileSearchController) {
    self.controller = controller
  }

  public var body: some View {
    Group {
      if showsHorizontalSplit {
        HStack(spacing: 0) {
          content
            .frame(width: LauncherLayout.detailListWidth)
            .frame(maxHeight: .infinity, alignment: .top)
          Divider()
          Group {
            if let file = controller.selected {
              FileDetailView(file: file)
            } else {
              ContentUnavailableView("No File Selected", systemImage: "doc")
            }
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxHeight: .infinity)
        .clipped()
      } else {
        content
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .overlay(alignment: .bottomLeading) {
      statusBadge
    }
  }

  /// Notices such as "Path copied" and the spinner for a search that refreshes visible results.
  @ViewBuilder
  private var statusBadge: some View {
    let refreshing = controller.isSearching && controller.status != .searching
    if refreshing || controller.notice != nil {
      HStack(spacing: 6) {
        if refreshing {
          ProgressView()
            .controlSize(.small)
        }
        if let notice = controller.notice {
          Text(notice)
            .lineLimit(1)
        }
      }
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.vertical, 5)
      .background(.regularMaterial, in: Capsule())
      .padding(10)
    }
  }

  private var showsHorizontalSplit: Bool {
    switch controller.status {
    case .recents, .results:
      true
    default:
      false
    }
  }

  @ViewBuilder
  private var content: some View {
    switch controller.status {
    case .idle:
      emptyState(
        symbol: "doc.text.magnifyingglass",
        title: "Search your files",
        detail: "Matches names and folders in your home directory. Type to begin."
      )
    case .searching:
      searchingState
    case .recents:
      list(title: "Recent Files")
    case .noRecents:
      emptyState(
        symbol: "clock",
        title: "No recent files",
        detail: "Files you open or modify will appear here."
      )
    case .unavailable:
      emptyState(
        symbol: "exclamationmark.triangle",
        title: "Spotlight is unavailable",
        detail: "Check System Settings > Siri & Spotlight, then try again."
      )
    case let .empty(query):
      emptyState(
        symbol: "magnifyingglass",
        title: "No matches",
        detail: "Nothing in your search scope matches \u{201C}\(query)\u{201D}."
      )
    case let .needsAccess(query):
      fileAccessState(query: query)
    case .results:
      list(title: "Results")
    }
  }

  private func fileAccessState(query: String) -> some View {
    VStack(spacing: 10) {
      Image(systemName: "folder.badge.plus")
        .font(.system(size: 28))
        .foregroundStyle(.secondary)
      Text("Allow access to search unindexed files")
        .font(.body.weight(.medium))
      Text(
        "Spotlight found no matches for “\(query)”. Choose only the folders Photon should search directly."
      )
      .font(.caption)
      .foregroundStyle(.secondary)
      .multilineTextAlignment(.center)
      if let accessNotice = controller.accessNotice {
        Text(accessNotice)
          .font(.caption)
          .foregroundStyle(.orange)
      }
      Button("Choose Folders…") {
        controller.requestFileAccess()
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var searchingState: some View {
    HStack(spacing: 8) {
      ProgressView()
        .controlSize(.small)
      Text("Searching\u{2026}")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.rowHeight)
    .padding(.vertical, LauncherLayout.listInset)
  }

  private func list(title: String) -> some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
          ForEach(controller.results) { item in
            FileResultRow(file: item.file, selected: item.id == controller.selectedID)
              .id(item.id)
              .onTapGesture(count: 2) {
                controller.select(item.file)
                if controller.performPrimaryAction() {
                  controller.onRequestDismiss?()
                }
              }
              .onTapGesture {
                controller.select(item.file)
              }
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, LauncherLayout.listInset)
      }
      .onChange(of: controller.selectedID) { _, newValue in
        if let newValue {
          proxy.scrollTo(newValue)
        }
      }
    }
    .frame(maxHeight: .infinity)
  }

  private func emptyState(symbol: String, title: String, detail: String) -> some View {
    VStack(spacing: 6) {
      Image(systemName: symbol)
        .font(.system(size: 28))
        .foregroundStyle(.tertiary)
      Text(title)
        .font(.body.weight(.medium))
      Text(detail)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct FileResultRow: View {
  let file: FileResult
  let selected: Bool

  var body: some View {
    HStack(spacing: 12) {
      Image(nsImage: FileIconCache.shared.icon(for: file))
        .resizable()
        .interpolation(.high)
        .frame(width: LauncherLayout.iconSize, height: LauncherLayout.iconSize)
      // The parent path shows only when it fits next to the full name.
      ViewThatFits(in: .horizontal) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          name
          Text(PathFormatter.parentDisplay(for: file.path, maxLength: 28))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        name
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.rowHeight)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(selected ? Color.primary.opacity(0.09) : Color.clear)
    )
    .contentShape(Rectangle())
  }

  private var name: some View {
    Text(file.displayName)
      .font(.system(size: 14, weight: .medium))
      .lineLimit(1)
  }
}

struct FileDetailView: View {
  let file: FileResult
  @StateObject private var loader = FilePreviewLoader()

  private struct Row: Identifiable {
    let label: String
    let value: String

    var id: String {
      label
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      preview
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      metadata
    }
    .clipped()
    .task(id: file.id) {
      loader.load(file, size: CGSize(width: 420, height: 300), scale: NSScreen.main?.backingScaleFactor ?? 2)
    }
  }

  @ViewBuilder
  private var preview: some View {
    if let image = loader.image {
      Image(nsImage: image)
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(22)
    } else {
      Image(nsImage: FileIconCache.shared.icon(for: file))
        .resizable()
        .interpolation(.high)
        .scaledToFit()
        .frame(width: 96, height: 96)
    }
  }

  /// Takes its natural height so every row stays visible. The preview above shrinks to fit.
  private var metadata: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Metadata")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.bottom, 6)
      ForEach(rows) { row in
        HStack(alignment: .firstTextBaseline, spacing: 16) {
          Text(row.label)
            .foregroundStyle(.secondary)
          Spacer(minLength: 12)
          Text(row.value)
            .lineLimit(1)
            .truncationMode(.middle)
            .textSelection(.enabled)
        }
        .font(.system(size: 13))
        .padding(.vertical, 3)
        .overlay(alignment: .bottom) {
          Divider()
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.top, 10)
    .padding(.bottom, 6)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.bottom, LauncherLayout.detailFooterSafeInset)
  }

  private var rows: [Row] {
    [
      Row(label: "Name", value: file.displayName),
      Row(label: "Where", value: PathFormatter.abbreviatingHome(file.parentPath)),
      Row(label: "Type", value: file.kind),
      Row(label: "Size", value: sizeText),
      Row(label: "Created", value: dateText(file.created)),
      Row(label: "Modified", value: dateText(file.modified)),
    ]
  }

  private var sizeText: String {
    guard let size = file.size, !file.isFolder else {
      return "\u{2014}"
    }
    return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
  }

  private func dateText(_ date: Date?) -> String {
    date?.formatted(date: .abbreviated, time: .shortened) ?? "\u{2014}"
  }
}

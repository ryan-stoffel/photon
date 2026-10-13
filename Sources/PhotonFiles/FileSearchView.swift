import AppKit
import PhotonCore
import SwiftUI

/// Results area and footer of the launcher while it is in file mode.
public struct FileSearchView: View {
  @ObservedObject private var controller: FileSearchController
  @State private var scrollTracker = ListScrollTracker()

  /// Scroll target for the section header, so selecting the first row shows it.
  private static let headerID = "files.list.header"

  public init(controller: FileSearchController) {
    self.controller = controller
  }

  public var body: some View {
    VStack(spacing: 0) {
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
      Divider()
      footer
    }
  }

  /// Left: folder icon, "Files", a notice such as "Path copied", and the spinner while a search
  /// refreshes visible results. Right: the Enter action and the ⌘K hint while a file is selected.
  private var footer: some View {
    HStack(spacing: 10) {
      Image(systemName: "folder")
        .font(.system(size: 12, weight: .medium))
      Text("Files")
        .fontWeight(.medium)
      if let notice = controller.notice {
        Text("\u{00B7}")
        Text(notice)
          .lineLimit(1)
      }
      if controller.isSearching, controller.status != .searching {
        ProgressView()
          .controlSize(.small)
      }
      Spacer(minLength: 12)
      if controller.selected != nil {
        FooterKeyHint(label: controller.settings.defaultAction.title, keys: ["\u{21B5}"], emphasized: true)
        Rectangle()
          .fill(Color.primary.opacity(0.15))
          .frame(width: 1, height: 14)
        FooterKeyHint(label: "Actions", keys: ["\u{2318}", "K"])
      }
    }
    .font(.system(size: 13))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
    .frame(height: LauncherLayout.footerHeight)
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
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, LauncherLayout.rowHorizontalPadding)
            .padding(.vertical, 8)
            .id(Self.headerID)
          ForEach(controller.results) { item in
            FileResultRow(file: item.file, selected: item.id == controller.selectedID)
              .id(item.id)
              .listScrollRow(item.id, tracker: scrollTracker)
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
      .listScrollViewport(scrollTracker)
      .onChange(of: controller.selectedID) { _, newValue in
        guard let newValue else {
          return
        }
        if newValue == controller.results.first?.id {
          proxy.scrollTo(Self.headerID, anchor: .top)
        } else {
          scrollTracker.reveal(newValue, in: controller.results.map(\.id), with: proxy)
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

/// "Open ↵": the label first, then each key in a small cap. Matches the launcher footer.
private struct FooterKeyHint: View {
  let label: String
  let keys: [String]
  var emphasized = false

  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .fontWeight(emphasized ? .medium : .regular)
        .foregroundStyle(emphasized ? .primary : .secondary)
        .padding(.trailing, 4)
      ForEach(keys, id: \.self) { key in
        Text(key)
          .font(.system(size: 12, weight: .medium))
          .frame(minWidth: 20, minHeight: 20)
          .padding(.horizontal, 2)
          .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.08)))
      }
    }
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
    .padding(.horizontal, LauncherLayout.rowHorizontalPadding)
    .frame(height: LauncherLayout.rowHeight)
    .background(
      RoundedRectangle(cornerRadius: LauncherLayout.rowCornerRadius, style: .continuous)
        .fill(selected ? Color.primary.opacity(0.1) : Color.clear)
    )
    .contentShape(Rectangle())
  }

  private var name: some View {
    Text(file.displayName)
      .font(.system(size: 14))
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

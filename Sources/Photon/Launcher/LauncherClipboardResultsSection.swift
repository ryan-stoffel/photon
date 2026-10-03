import AppKit
import Foundation
import PhotonClipboard
import PhotonCore
import SwiftUI

/// The one-row clipboard state: history is off, or a filter matches nothing. Results always
/// render in `LauncherClipboardDetailSplitView`.
struct LauncherClipboardResultsSection: View {
  @ObservedObject var model: LauncherViewModel

  var body: some View {
    HStack {
      Text(model.clipboard?.compactEmptyMessage ?? "")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.rowHeight)
    .padding(.horizontal, 8)
    .padding(.vertical, LauncherLayout.listInset)
    .frame(height: LauncherLayout.listHeight(rowCount: 1), alignment: .top)
  }
}

struct LauncherClipboardDetailSplitView: View {
  @ObservedObject var model: LauncherViewModel

  var body: some View {
    if let clipboard = model.clipboard {
      ClipboardDetailSplitBody(clipboard: clipboard)
    } else {
      ContentUnavailableView("No Clipboard Item", systemImage: "clipboard")
    }
  }
}

private struct ClipboardDetailSplitBody: View {
  @ObservedObject var clipboard: ClipboardHistoryViewModel

  var body: some View {
    if clipboard.results.isEmpty, !clipboard.query.isEmpty {
      ContentUnavailableView.search(text: clipboard.query)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
      HStack(spacing: 0) {
        historyList
          .frame(width: LauncherLayout.detailListWidth)
          .frame(maxHeight: .infinity, alignment: .top)
        Divider()
        Group {
          if let item = clipboard.selectedItem {
            // A fresh identity per entry, so the previous entry's state never shows under new metadata.
            ClipboardDetailView(item: item, manager: clipboard.manager)
              .id(item.id)
          } else {
            ContentUnavailableView("No Clipboard Item", systemImage: "clipboard")
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .frame(maxHeight: .infinity)
      .clipped()
    }
  }

  /// An empty query with pinned entries splits the list into Pinned and Recent. Search sorts
  /// pinned entries first for an empty query, so the sections match keyboard order.
  private var historyList: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        LazyVStack(alignment: .leading, spacing: 0) {
          let pinned = clipboard.query.isEmpty ? clipboard.results.filter(\.isPinned) : []
          if pinned.isEmpty {
            rows(clipboard.results)
          } else {
            let recent = clipboard.results.filter { !$0.isPinned }
            sectionHeader("Pinned")
            rows(pinned)
            if !recent.isEmpty {
              sectionHeader("Recent")
              rows(recent)
            }
          }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, LauncherLayout.listInset)
      }
      .onChange(of: clipboard.selectedID) { _, selectedID in
        if let selectedID {
          proxy.scrollTo(selectedID)
        }
      }
    }
    .frame(maxHeight: .infinity)
  }

  private func rows(_ items: [ClipboardItem]) -> some View {
    ForEach(items) { item in
      ClipboardHistoryObservingRow(item: item, clipboard: clipboard)
        .id(item.id)
        .contentShape(Rectangle())
        .contextMenu {
          contextMenu(for: item)
        }
        .onTapGesture(count: 2) {
          clipboard.perform(clipboard.manager.settings.pasteBehavior, on: item)
        }
        .onTapGesture {
          clipboard.selectedID = item.id
        }
    }
  }

  /// The same entry actions as the ⌘K panel.
  @ViewBuilder
  private func contextMenu(for item: ClipboardItem) -> some View {
    let primary = clipboard.manager.settings.pasteBehavior
    Button(primary.label) {
      clipboard.perform(primary, on: item)
    }
    Button(primary.other.label) {
      clipboard.perform(primary.other, on: item)
    }
    Divider()
    Button(item.isPinned ? "Unpin Entry" : "Pin Entry") {
      clipboard.togglePin(item)
    }
    Button("Delete Entry", role: .destructive) {
      clipboard.delete(item)
    }
  }

  /// Matches the launcher's Suggestions header.
  private func sectionHeader(_ title: String) -> some View {
    Text(title)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.vertical, 2)
      .accessibilityAddTraits(.isHeader)
  }
}

/// Observes the clipboard VM so Up/Down selection highlight redraws even when
/// the results array identity is unchanged.
private struct ClipboardHistoryObservingRow: View {
  let item: ClipboardItem
  @ObservedObject var clipboard: ClipboardHistoryViewModel

  var body: some View {
    ClipboardLauncherRow(item: item, isSelected: item.id == clipboard.selectedID)
  }
}

/// Preview and Information table for one entry. The preview renders `item.text`, which capture
/// caps at `ClipboardItem.inlineTextLimit`. Counts and file sizes load off the main thread.
private struct ClipboardDetailView: View {
  let item: ClipboardItem
  let manager: ClipboardManager
  @State private var image: NSImage?
  /// Counts over the full text, including the part stored as a blob.
  @State private var textCounts: (characters: Int, words: Int)?
  /// Total size of the copied files. Nil while loading, or when a path is missing or a folder.
  @State private var fileSize: String?

  var body: some View {
    VStack(spacing: 0) {
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      Divider()
      metadata
    }
    .clipped()
    .task(id: item.id) {
      switch item.kind {
      case .text, .link:
        let text = await manager.fullText(for: item) ?? ""
        textCounts = await Task.detached {
          (text.count, text.split(whereSeparator: \.isWhitespace).count)
        }.value
      case .image:
        image = await manager.image(for: item)
      case .file:
        let paths = item.filePaths
        fileSize = await Task.detached { Self.fileSize(paths) }.value
      }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch item.kind {
    case .image:
      if let image {
        Image(nsImage: image)
          .resizable()
          .interpolation(.high)
          .scaledToFit()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(24)
      } else {
        ProgressView()
          .controlSize(.small)
      }
    case .text, .link:
      ScrollView {
        if item.kind == .link, let text = item.text, let url = URL(string: text) {
          Link(text, destination: url)
            .font(.system(size: 15))
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
        } else {
          Text(item.text ?? "")
            .font(.system(size: 14, design: .monospaced))
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .textSelection(.enabled)
        }
      }
      .padding(20)
    case .file:
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(item.filePaths, id: \.self) { path in
            Label(path, systemImage: "doc")
              .textSelection(.enabled)
          }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(20)
      }
    }
  }

  private var metadata: some View {
    ScrollView(.vertical) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Information")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.bottom, 6)
        metadataRow("Source", item.sourceAppName ?? "Unknown app")
        metadataRow("Content type", item.kind.label)
        switch item.kind {
        case .text, .link:
          metadataRow("Characters", textCounts.map { "\($0.characters)" } ?? "—")
          metadataRow("Words", textCounts.map { "\($0.words)" } ?? "—")
        case .image:
          metadataRow("Dimensions", dimensions)
          metadataRow("Image size", formattedBytes)
        case .file:
          metadataRow("Items", "\(item.filePaths.count)")
          metadataRow("Size", fileSize ?? "—")
        }
        metadataRow("Copied", item.copiedAt.formatted(date: .abbreviated, time: .shortened))
      }
      .padding(.horizontal, 20)
      .padding(.top, 10)
      .padding(.bottom, 6)
    }
    .frame(height: LauncherLayout.detailMetadataHeight, alignment: .top)
    .padding(.bottom, LauncherLayout.detailFooterSafeInset)
    .clipped()
  }

  private func metadataRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 16) {
      Text(label)
        .foregroundStyle(.secondary)
      Spacer(minLength: 12)
      Text(value)
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

  /// Sum of the regular files' sizes, or nil when any path is missing or not a regular file.
  private nonisolated static func fileSize(_ paths: [String]) -> String? {
    var total: Int64 = 0
    for path in paths {
      let values = try? URL(fileURLWithPath: path).resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
      guard values?.isRegularFile == true, let size = values?.fileSize else {
        return nil
      }
      total += Int64(size)
    }
    return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
  }

  private var dimensions: String {
    guard let width = item.imageWidth, let height = item.imageHeight else {
      return "—"
    }
    return "\(width) × \(height)"
  }

  private var formattedBytes: String {
    ByteCountFormatter.string(fromByteCount: Int64(item.byteCount), countStyle: .file)
  }
}

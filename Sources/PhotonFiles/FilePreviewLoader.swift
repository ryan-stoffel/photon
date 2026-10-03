import AppKit
import Combine
import Foundation
import QuickLookThumbnailing

@MainActor
final class FilePreviewLoader: ObservableObject {
  @Published private(set) var image: NSImage?

  private var task: Task<Void, Never>?

  /// Shows the cached Finder icon right away, then swaps in the Quick Look thumbnail.
  func load(_ file: FileResult, size: CGSize, scale: CGFloat) {
    task?.cancel()
    image = FileIconCache.shared.icon(for: file)
    task = Task {
      let request = QLThumbnailGenerator.Request(
        fileAt: file.url,
        size: size,
        scale: scale,
        representationTypes: [.thumbnail, .icon]
      )
      let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
      guard !Task.isCancelled else {
        return
      }
      image = representation?.nsImage ?? FileIconCache.shared.icon(for: file)
    }
  }
}

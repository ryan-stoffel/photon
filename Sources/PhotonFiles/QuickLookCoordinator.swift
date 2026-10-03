import AppKit
import QuickLookUI

/// Drives the shared `QLPreviewPanel` for the selected file. The launcher
/// panel forwards `QLPreviewPanelController` requests here so the panel finds
/// its data source through the responder chain; the source is also assigned
/// directly as a fallback.
@MainActor
public final class QuickLookCoordinator: NSObject {
  public private(set) var previewURL: URL?
  /// Called after the panel closes for any reason so the owner can take focus back.
  public var onDidClose: (@MainActor () -> Void)?
  /// Called with -1 or 1 when Up or Down is pressed while the panel is key.
  public var onMove: (@MainActor (Int) -> Void)?

  public var isVisible: Bool {
    QLPreviewPanel.sharedPreviewPanelExists() && QLPreviewPanel.shared().isVisible
  }

  public func show(_ url: URL) {
    previewURL = url
    let panel = QLPreviewPanel.shared()
    guard let panel else {
      return
    }
    if panel.dataSource == nil {
      panel.dataSource = self
      panel.delegate = self
    }
    if !panel.isVisible {
      panel.makeKeyAndOrderFront(nil)
    }
    panel.reloadData()
  }

  public func hide() {
    guard isVisible else {
      return
    }
    QLPreviewPanel.shared().orderOut(nil)
    onDidClose?()
  }

  public func toggle(_ url: URL?) {
    if isVisible {
      hide()
    } else if let url {
      show(url)
    }
  }

  /// Keeps the preview in sync with the selection while the panel is open.
  public func update(_ url: URL?) {
    previewURL = url
    guard isVisible else {
      return
    }
    if url == nil {
      hide()
    } else {
      QLPreviewPanel.shared().reloadData()
    }
  }

  // MARK: QLPreviewPanelController (forwarded by the launcher panel)

  public func beginControl(of panel: QLPreviewPanel) {
    panel.dataSource = self
    panel.delegate = self
  }

  public func endControl(of panel: QLPreviewPanel) {
    if panel.dataSource === self {
      panel.dataSource = nil
      panel.delegate = nil
    }
    previewURL = nil
    onDidClose?()
  }
}

/// Quick Look calls its data source on the main thread; `@preconcurrency`
/// lets these main-actor methods satisfy the nonisolated protocol.
extension QuickLookCoordinator: @preconcurrency QLPreviewPanelDataSource {
  public func numberOfPreviewItems(in _: QLPreviewPanel!) -> Int {
    previewURL == nil ? 0 : 1
  }

  public func previewPanel(_: QLPreviewPanel!, previewItemAt _: Int) -> (any QLPreviewItem)! {
    previewURL.map { $0 as NSURL }
  }
}

/// The panel is key while it is open, so the launcher never sees these keys. Up and Down
/// move the Files selection (the preview follows it) and ⌘Y closes the panel. Esc and
/// Space stay with the panel.
extension QuickLookCoordinator: @preconcurrency QLPreviewPanelDelegate {
  public func previewPanel(_: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
    guard let event, event.type == .keyDown else {
      return false
    }
    let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
    switch event.keyCode {
    case 125 where modifiers.isEmpty:
      onMove?(1)
    case 126 where modifiers.isEmpty:
      onMove?(-1)
    case 16 where modifiers == .command:
      hide()
    default:
      return false
    }
    return true
  }
}

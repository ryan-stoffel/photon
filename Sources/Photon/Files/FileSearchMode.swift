import AppKit
import Combine
import PhotonCore
import PhotonFiles
import QuickLookUI
import SwiftUI

/// Adapts `PhotonFiles.FileSearchController` to the launcher's mode protocol.
@MainActor
final class FileSearchMode: LauncherMode {
  let id = "files"
  let title = "Files"
  let placeholder = "Search files"
  let prefixes = ["/", "f "]
  let activationCommandID: String? = FilesProvider.searchCommandID
  let inlineProviderID: String? = "files"

  let controller: FileSearchController
  private weak var host: (any LauncherModeHost)?
  private var layoutCancellable: AnyCancellable?

  init(controller: FileSearchController) {
    self.controller = controller
  }

  var holdsFocus: Bool {
    controller.holdsFocus
  }

  var prefersCompactLauncherLayout: Bool {
    controller.prefersCompactLauncherLayout
  }

  func attach(host: any LauncherModeHost) {
    self.host = host
    controller.onRequestFocus = { [weak host] in
      host?.modeRequestsFocus()
    }
    controller.onRequestDismiss = { [weak host] in
      host?.modeRequestsDismiss()
    }
    controller.onRequestActivation = { [weak host] in
      host?.modeRequestsActivation()
    }
    layoutCancellable = controller.objectWillChange
      .receive(on: RunLoop.main)
      .sink { [weak host] in
        host?.modeRequestsLayoutUpdate()
      }
  }

  func activate(query: String) {
    controller.activate(query: query)
  }

  func update(query: String) {
    controller.update(query: query)
  }

  func deactivate() {
    controller.deactivate()
  }

  func moveSelection(_ delta: Int) {
    controller.moveSelection(delta)
  }

  func performPrimaryAction() -> Bool {
    controller.performPrimaryAction()
  }

  /// The Settings > Files Enter action, the other one (⌘↵), Quick Look (⌘Y) and Copy Path (⌥⌘C).
  /// Empty while no file is selected.
  func actions() -> [LauncherAction] {
    guard controller.selected != nil else {
      return []
    }
    let controller = controller
    let primary = controller.settings.defaultAction
    return [
      LauncherAction(id: primary.actionID, title: primary.title, symbol: primary.symbol) {
        controller.performPrimaryAction()
      },
      LauncherAction(
        id: primary.other.actionID,
        title: primary.other.title,
        symbol: primary.other.symbol,
        shortcut: .commandReturn
      ) {
        controller.performSecondaryAction()
      },
      LauncherAction(
        id: "file.quickLook",
        title: "Quick Look",
        symbol: "eye",
        shortcut: LauncherShortcut(keyCode: 16, modifiers: .command, key: "Y")
      ) {
        controller.toggleQuickLook()
        return false
      },
      LauncherAction(
        id: "file.copyPath",
        title: "Copy Path",
        symbol: "doc.on.clipboard",
        shortcut: LauncherShortcut(keyCode: 8, modifiers: [.option, .command], key: "C")
      ) {
        controller.copyPath()
        return false
      },
    ]
  }

  func handle(_ event: NSEvent) -> Bool {
    controller.handle(event)
  }

  func icon(for command: Command) -> NSImage? {
    guard let path = FilesProvider.path(forCommandID: command.id) else {
      return nil
    }
    return FileIconCache.shared.icon(forPath: path)
  }

  func makeResultsView() -> AnyView {
    AnyView(FileSearchView(controller: controller))
  }

  var acceptsPreviewPanelControl: Bool {
    true
  }

  func beginPreviewPanelControl(_ panel: QLPreviewPanel) {
    controller.quickLook.beginControl(of: panel)
  }

  func endPreviewPanelControl(_ panel: QLPreviewPanel) {
    controller.quickLook.endControl(of: panel)
  }
}

extension FileDefaultAction {
  var actionID: String {
    self == .open ? "file.open" : "file.showInFinder"
  }

  var symbol: String {
    self == .open ? "arrow.up.forward.app" : "folder"
  }
}

import AppKit
import SwiftUI

struct NotesOverlayView: View {
  let kind: NotesWindow.OverlayKind
  @ObservedObject var switcher: NoteSwitcherModel
  @ObservedObject var actions: NoteActionsModel
  var onDismiss: () -> Void
  var onStyle: (MarkdownFormatStyle) -> Void

  var body: some View {
    ZStack {
      if kind == .switcher || kind == .actions {
        Color.black.opacity(0.2)
          .ignoresSafeArea()
          .onTapGesture(perform: onDismiss)
        VStack {
          Spacer().frame(height: 88)
          if kind == .switcher {
            NoteSwitcherView(model: switcher)
          }
          if kind == .actions {
            NoteActionsView(model: actions)
          }
          Spacer()
        }
      }
      if kind == .format {
        // The overlay is only `formatBarStrip` tall here, so nothing above the bar may claim height.
        VStack(spacing: 0) {
          Spacer(minLength: 0)
          NoteFormatBar(onStyle: onStyle, onClose: onDismiss)
        }
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .allowsHitTesting(kind != .none)
  }
}

extension NotesWindow {
  func rebuildOverlay() {
    overlayHosting?.removeFromSuperview()
    overlayHosting = nil
    // The format bar strip overlaps the editor's bottom 32 pt, so the caret line must scroll above it.
    // Switching to manual insets keeps the automatic titlebar inset already applied at the top.
    let reservesFormatBar = overlayKind == .format
    scrollView.automaticallyAdjustsContentInsets = !reservesFormatBar
    scrollView.contentInsets.bottom = reservesFormatBar ? 32 : 0
    guard overlayKind != .none else {
      overlayContainer.isHidden = true
      return
    }
    let view = NotesOverlayView(
      kind: overlayKind,
      switcher: switcherModel,
      actions: actionsModel,
      onDismiss: { [weak self] in
        self?.dismissOverlay()
      },
      onStyle: { [weak self] style in
        self?.applyFormat(style)
      }
    )
    let host = NSHostingView(rootView: view)
    host.translatesAutoresizingMaskIntoConstraints = false
    overlayContainer.addSubview(host)
    NSLayoutConstraint.activate([
      host.leadingAnchor.constraint(equalTo: overlayContainer.leadingAnchor),
      host.trailingAnchor.constraint(equalTo: overlayContainer.trailingAnchor),
      host.topAnchor.constraint(equalTo: overlayContainer.topAnchor),
      host.bottomAnchor.constraint(equalTo: overlayContainer.bottomAnchor),
    ])
    overlayHosting = host
    overlayContainer.isHidden = false
    // The format bar is a toolbar, not a modal: the editor keeps focus while it shows.
    formatBarStrip.isActive = overlayKind == .format
    panel.makeFirstResponder(overlayKind == .format ? textView : host)
  }
}

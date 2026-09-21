import AppKit
import PhotonCore
import SwiftUI

enum PhotonSettingsChrome {
  static let windowSize = NSSize(width: 760, height: 540)
  static let sidebarWidth: CGFloat = 188
  static let trafficLightClearance: CGFloat = 36
  static let cardCornerRadius: CGFloat = 12
  static let rowCornerRadius: CGFloat = 8
  static let contentIdentifier = NSUserInterfaceItemIdentifier("photon.settings.chrome")

  /// Matches the launcher panel: Liquid Glass / vibrancy, 12pt continuous corners, clear window.
  @MainActor
  static func applyWindowChrome(_ window: NSWindow) {
    window.title = "Settings"
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.styleMask.insert(.fullSizeContentView)
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.isMovableByWindowBackground = true
    window.minSize = NSSize(width: 680, height: 420)
    guard let content = window.contentView, content.identifier != contentIdentifier else {
      return
    }
    let size = content.bounds.size.width > 1
      ? content.bounds.size
      : windowSize
    content.identifier = NSUserInterfaceItemIdentifier("photon.settings.host")
    let wrapped = PhotonPanelChrome.embed(
      content,
      frame: NSRect(origin: .zero, size: size),
      cornerRadius: LauncherLayout.cornerRadius,
      material: .popover
    )
    wrapped.identifier = contentIdentifier
    window.contentView = wrapped
  }

  @MainActor
  static func makeWindow(rootView: some View) -> PhotonSettingsWindow {
    let host = NSHostingView(rootView: rootView)
    host.safeAreaRegions = []
    host.sizingOptions = []
    host.frame = NSRect(origin: .zero, size: windowSize)
    let window = PhotonSettingsWindow(
      contentRect: NSRect(origin: .zero, size: windowSize),
      styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.setContentSize(windowSize)
    let chrome = PhotonPanelChrome.embed(
      host,
      frame: NSRect(origin: .zero, size: windowSize),
      cornerRadius: LauncherLayout.cornerRadius,
      material: .popover
    )
    chrome.identifier = contentIdentifier
    window.contentView = chrome
    applyWindowChrome(window)
    return window
  }
}

final class PhotonSettingsWindow: NSWindow {
  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }
}

final class PhotonSettingsWindowCloseDelegate: NSObject, NSWindowDelegate {
  var onClose: (() -> Void)?

  func windowWillClose(_: Notification) {
    onClose?()
  }
}

struct PhotonSettingsWindowBinder: NSViewRepresentable {
  func makeNSView(context _: Context) -> NSView {
    let view = NSView(frame: .zero)
    view.identifier = NSUserInterfaceItemIdentifier("photon.settings.binder")
    return view
  }

  func updateNSView(_ nsView: NSView, context _: Context) {
    DispatchQueue.main.async {
      if let window = nsView.window {
        PhotonSettingsChrome.applyWindowChrome(window)
      }
    }
  }
}

struct PhotonSettingsHairline: View {
  var emphasized = false

  var body: some View {
    if emphasized {
      VStack(spacing: 0) {
        Rectangle()
          .fill(Color.primary.opacity(0.16))
          .frame(height: 0.5)
        Rectangle()
          .fill(Color.primary.opacity(0.06))
          .frame(height: 0.5)
      }
      .frame(height: LauncherLayout.hairline)
    } else {
      Rectangle()
        .fill(Color.primary.opacity(0.08))
        .frame(height: LauncherLayout.hairline)
    }
  }
}

struct PhotonSettingsPage<Content: View>: View {
  let title: String
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .font(.system(size: 20, weight: .medium))
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, height: LauncherLayout.searchFieldHeight, alignment: .leading)
      PhotonSettingsHairline(emphasized: true)
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

struct PhotonSettingsCard<Content: View>: View {
  var title: String?
  var footer: String?
  @ViewBuilder var content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title {
        Text(title)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.primary)
          .padding(.horizontal, 4)
      }
      VStack(alignment: .leading, spacing: 0) {
        content()
      }
      .padding(.vertical, 6)
      .padding(.horizontal, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: PhotonSettingsChrome.cardCornerRadius, style: .continuous)
          .fill(Color.primary.opacity(0.05))
      )
      .overlay(
        RoundedRectangle(cornerRadius: PhotonSettingsChrome.cardCornerRadius, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08), lineWidth: LauncherLayout.hairline)
      )
      if let footer {
        Text(footer)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
      }
    }
  }
}

struct PhotonSettingsRow<Accessory: View>: View {
  let title: String
  var detail: String?
  @ViewBuilder var accessory: () -> Accessory

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title)
          .font(.system(size: 14, weight: .medium))
          .lineLimit(1)
          .fixedSize(horizontal: true, vertical: false)
        if let detail {
          Text(detail)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
      }
      .layoutPriority(1)
      Spacer(minLength: 8)
      accessory()
    }
    .padding(.horizontal, 10)
    .frame(minHeight: LauncherLayout.rowHeight)
  }
}

struct PhotonSettingsCaption: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 12))
      .foregroundStyle(.secondary)
      .padding(.horizontal, 10)
      .padding(.bottom, 8)
  }
}

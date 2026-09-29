import AppKit
import Carbon
import PhotonCore
import SwiftUI

/// Visible copy for the first-run window. The parity harness matches `step`.
enum WelcomeCopy {
  static let step = "Welcome"
  static let productName = "Photon"
  static let grantButton = "Grant Access"
  static let grantingButton = "Waiting for macOS…"

  static var shortcutCaption: String {
    "Press this to open \(productName)."
  }
}

@MainActor
final class WelcomeModel: ObservableObject {
  let hotkey: HotkeyCombo
  @Published var isGranting = false
  var grant: () -> Void = {}

  init(hotkey: HotkeyCombo) {
    self.hotkey = hotkey
  }
}

struct WelcomeView: View {
  @ObservedObject var model: WelcomeModel

  var body: some View {
    VStack(spacing: 0) {
      Spacer(minLength: 0)
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 96, height: 96)
        .accessibilityLabel(WelcomeCopy.productName)
      Text(WelcomeCopy.productName)
        .font(.system(size: 28, weight: .semibold))
        .padding(.top, 16)
      Text(WelcomeCopy.shortcutCaption)
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
        .padding(.top, 6)
      WelcomeKeycaps(labels: model.hotkey.keycapLabels, accessibilityLabel: model.hotkey.displayString)
        .padding(.top, 28)
      Spacer(minLength: 0)
      Button(model.isGranting ? WelcomeCopy.grantingButton : WelcomeCopy.grantButton) {
        model.grant()
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(model.isGranting)
      .keyboardShortcut(.defaultAction)
    }
    .padding(.horizontal, 40)
    .padding(.top, PhotonSettingsChrome.trafficLightClearance)
    .padding(.bottom, 28)
    .frame(width: WelcomeWindow.contentWidth, height: WelcomeWindow.contentHeight)
    .background(Color.clear)
    .overlay(WelcomeChromeStroke())
  }
}

/// Keycaps drawn from `HotkeyCombo.keycapLabels` — the configured launcher shortcut.
private struct WelcomeKeycaps: View {
  let labels: [String]
  let accessibilityLabel: String

  var body: some View {
    HStack(spacing: 8) {
      ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
        WelcomeKeycap(label: label)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }
}

private struct WelcomeKeycap: View {
  let label: String

  var body: some View {
    Text(label)
      .font(.system(size: label.count > 1 ? 20 : 28, weight: .medium))
      .frame(minWidth: label.count > 2 ? 108 : 64, minHeight: 64)
      .padding(.horizontal, 12)
      .background(keyShape.fill(Color.primary.opacity(0.08)))
      .overlay(keyShape.strokeBorder(Color.primary.opacity(0.16), lineWidth: 1))
  }

  private var keyShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: PhotonSettingsChrome.rowCornerRadius, style: .continuous)
  }
}

private struct WelcomeChromeStroke: View {
  var body: some View {
    RoundedRectangle(cornerRadius: LauncherLayout.cornerRadius, style: .continuous)
      .strokeBorder(Color.primary.opacity(0.1), lineWidth: LauncherLayout.hairline)
      .allowsHitTesting(false)
  }
}

/// One window on the active space. Same material and corners as the launcher.
final class WelcomeWindow: NSWindow {
  static let identifier = NSUserInterfaceItemIdentifier("photon.welcome")
  static let contentWidth: CGFloat = 600
  static let contentHeight: CGFloat = 460

  var onDismiss: (() -> Void)?
  var allowsDismiss = true

  static func make(model: WelcomeModel) -> WelcomeWindow {
    let size = NSSize(width: contentWidth, height: contentHeight)
    let window = WelcomeWindow(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.titled, .closable, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )
    window.title = WelcomeCopy.step
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.identifier = identifier
    window.isReleasedWhenClosed = false
    window.isRestorable = false
    window.level = .normal
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.isMovableByWindowBackground = true
    let host = NSHostingView(rootView: WelcomeView(model: model))
    host.safeAreaRegions = []
    host.sizingOptions = []
    host.frame = NSRect(origin: .zero, size: size)
    let chrome = PhotonPanelChrome.embed(
      host,
      frame: NSRect(origin: .zero, size: size),
      cornerRadius: LauncherLayout.cornerRadius,
      material: .popover
    )
    window.contentView = chrome
    chrome.wantsLayer = true
    chrome.layer?.cornerRadius = LauncherLayout.cornerRadius
    chrome.layer?.cornerCurve = .continuous
    window.setContentSize(size)
    window.center()
    return window
  }

  override var canBecomeKey: Bool {
    true
  }

  override var canBecomeMain: Bool {
    true
  }

  override func cancelOperation(_: Any?) {
    dismissIfAllowed()
  }

  override func keyDown(with event: NSEvent) {
    if allowsDismiss, Self.dismisses(event.keyCode) {
      dismissIfAllowed()
      return
    }
    super.keyDown(with: event)
  }

  fileprivate func dismissIfAllowed() {
    guard allowsDismiss else {
      return
    }
    onDismiss?()
  }

  fileprivate static func dismisses(_ keyCode: UInt16) -> Bool {
    keyCode == UInt16(kVK_Escape)
  }
}

@MainActor
final class WelcomeController {
  var onFinish: (() -> Void)?
  var onGrant: (() async -> Void)?

  private var window: WelcomeWindow?
  private var model: WelcomeModel?
  private var closeDelegate: WelcomeCloseDelegate?
  private var keyMonitor: Any?
  private var grantTask: Task<Void, Never>?
  private(set) var presentationGeneration = 0
  private var finished = false

  var isVisible: Bool {
    window?.isVisible == true
  }

  var windowNumber: Int {
    guard isVisible, let window else {
      return 0
    }
    return window.windowNumber
  }

  var windowTitle: String {
    window?.title ?? ""
  }

  var hotkeyDisplay: String {
    model?.hotkey.displayString ?? ""
  }

  var keycapLabels: [String] {
    model?.hotkey.keycapLabels ?? []
  }

  var frameSize: NSSize {
    window?.frame.size ?? .zero
  }

  var isOpaqueWindow: Bool {
    window?.isOpaque ?? true
  }

  var chromeCornerRadius: CGFloat {
    window?.contentView?.layer?.cornerRadius ?? 0
  }

  func present(hotkey: HotkeyCombo) {
    presentationGeneration += 1
    grantTask?.cancel()
    grantTask = nil
    finished = false
    tearDown()
    let model = WelcomeModel(hotkey: hotkey)
    let window = WelcomeWindow.make(model: model)
    let box = WelcomeBox(self)
    model.grant = {
      MainActor.assumeIsolated {
        box.value?.grantAccess()
      }
    }
    let closeDelegate = WelcomeCloseDelegate()
    closeDelegate.onClose = {
      MainActor.assumeIsolated {
        box.value?.dismiss()
      }
    }
    window.onDismiss = {
      MainActor.assumeIsolated {
        box.value?.dismiss()
      }
    }
    window.delegate = closeDelegate
    self.window = window
    self.model = model
    self.closeDelegate = closeDelegate
    installKeyMonitor()
    NSApp.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }

  func grantAccess() {
    guard grantTask == nil, let model, !model.isGranting else {
      return
    }
    let id = presentationGeneration
    model.isGranting = true
    window?.allowsDismiss = false
    grantTask = Task { [weak self] in
      await self?.onGrant?()
      guard let self, presentationGeneration == id, !Task.isCancelled else {
        return
      }
      dismiss()
    }
  }

  func dismiss() {
    guard !finished else {
      return
    }
    finished = true
    grantTask?.cancel()
    grantTask = nil
    tearDown()
    NSApp.setActivationPolicy(.accessory)
    let finish = onFinish
    onFinish = nil
    finish?()
  }

  private func tearDown() {
    removeKeyMonitor()
    window?.delegate = nil
    window?.orderOut(nil)
    window?.contentView = nil
    window = nil
    model = nil
    closeDelegate = nil
  }

  private func installKeyMonitor() {
    removeKeyMonitor()
    let box = WelcomeBox(self)
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      let keyCode = event.keyCode
      let windowNumber = event.window?.windowNumber ?? 0
      let handled = MainActor.assumeIsolated {
        box.value?.handleKey(keyCode: keyCode, windowNumber: windowNumber) ?? false
      }
      return handled ? nil : event
    }
  }

  private func removeKeyMonitor() {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
    }
    keyMonitor = nil
  }

  private func handleKey(keyCode: UInt16, windowNumber: Int) -> Bool {
    guard window?.allowsDismiss == true, windowNumber == window?.windowNumber, isVisible else {
      return false
    }
    guard WelcomeWindow.dismisses(keyCode) else {
      return false
    }
    dismiss()
    return true
  }
}

private final class WelcomeCloseDelegate: NSObject, NSWindowDelegate {
  var onClose: (() -> Void)?

  func windowShouldClose(_ window: NSWindow) -> Bool {
    guard (window as? WelcomeWindow)?.allowsDismiss == true else {
      return false
    }
    onClose?()
    return false
  }
}

private struct WelcomeBox: @unchecked Sendable {
  weak var value: WelcomeController?

  init(_ value: WelcomeController) {
    self.value = value
  }
}

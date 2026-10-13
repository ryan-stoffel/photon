import AppKit
import PhotonKeybinds
import SwiftUI

struct HotkeyRecorder: NSViewRepresentable {
  @Binding var combo: HotkeyCombo

  func makeNSView(context _: Context) -> HotkeyRecorderView {
    let view = HotkeyRecorderView()
    view.combo = combo
    view.onChange = { combo = $0 }
    return view
  }

  func updateNSView(_ nsView: HotkeyRecorderView, context _: Context) {
    nsView.combo = combo
    nsView.onChange = { combo = $0 }
    nsView.refresh()
  }
}

/// Recorder for an optional shortcut. Shows "None" when unset; Delete while recording clears it.
/// `title` overrides how a shortcut is displayed; `onRecordingChanged` reports when recording starts and stops.
struct OptionalHotkeyRecorder: NSViewRepresentable {
  @Binding var combo: HotkeyCombo?
  var title: ((HotkeyCombo) -> String)?
  var onRecordingChanged: ((Bool) -> Void)?

  func makeNSView(context _: Context) -> HotkeyRecorderView {
    let view = HotkeyRecorderView()
    view.allowsClear = true
    configure(view)
    return view
  }

  func updateNSView(_ nsView: HotkeyRecorderView, context _: Context) {
    configure(nsView)
    nsView.refresh()
  }

  private func configure(_ view: HotkeyRecorderView) {
    view.combo = combo
    view.titleProvider = title
    view.onRecordingChanged = onRecordingChanged
    view.onChange = { combo = $0 }
    view.onClear = { combo = nil }
  }
}

final class HotkeyRecorderView: NSView {
  var combo: HotkeyCombo? = .defaultCombo
  var onChange: ((HotkeyCombo) -> Void)?
  var onClear: (() -> Void)?
  var onRecordingChanged: ((Bool) -> Void)?
  var titleProvider: ((HotkeyCombo) -> String)?
  var allowsClear = false

  private(set) var recording = false {
    didSet {
      if recording != oldValue {
        onRecordingChanged?(recording)
      }
    }
  }

  private let button = NSButton(title: "", target: nil, action: nil)

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    button.bezelStyle = .rounded
    button.setButtonType(.momentaryPushIn)
    button.target = self
    button.action = #selector(toggle)
    button.translatesAutoresizingMaskIntoConstraints = false
    addSubview(button)
    NSLayoutConstraint.activate([
      button.leadingAnchor.constraint(equalTo: leadingAnchor),
      button.trailingAnchor.constraint(equalTo: trailingAnchor),
      button.topAnchor.constraint(equalTo: topAnchor),
      button.bottomAnchor.constraint(equalTo: bottomAnchor),
      button.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
    ])
    refresh()
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var acceptsFirstResponder: Bool {
    true
  }

  func refresh() {
    if recording {
      button.title = "Press a shortcut"
    } else if let combo {
      button.title = titleProvider?(combo) ?? combo.displayString
    } else {
      button.title = "None"
    }
  }

  @objc
  private func toggle() {
    if recording {
      recording = false
    } else {
      // Take focus first so a recorder that is still active resigns before this one reports recording.
      window?.makeFirstResponder(self)
      recording = true
    }
    refresh()
  }

  /// Stops recording without changing the shortcut. Also runs when the window resigns key or goes away,
  /// because keybinds stay suspended while any recorder is recording.
  @objc
  private func cancelRecording() {
    guard recording else {
      return
    }
    recording = false
    refresh()
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
    guard let window else {
      cancelRecording()
      return
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(cancelRecording),
      name: NSWindow.didResignKeyNotification,
      object: window
    )
  }

  /// While recording, key equivalents such as ⌘W or ⌘Q are recorded instead of reaching the menu.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard recording else {
      return super.performKeyEquivalent(with: event)
    }
    keyDown(with: event)
    return true
  }

  override func keyDown(with event: NSEvent) {
    guard recording else {
      super.keyDown(with: event)
      return
    }
    let flags = UInt32(event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue)
    let carbon = HotkeyCombo.carbonModifiers(fromApple: flags)
    // Only bare Esc and Delete edit the recorder. With modifiers they are recorded like any other key.
    if carbon == 0, event.keyCode == UInt16(kVKEscape) {
      cancelRecording()
      return
    }
    if allowsClear, carbon == 0, event.keyCode == UInt16(kVKDelete) || event.keyCode == UInt16(kVKForwardDelete) {
      combo = nil
      onClear?()
      recording = false
      refresh()
      return
    }
    let next = HotkeyCombo(keyCode: UInt32(event.keyCode), carbonModifiers: carbon)
    guard KeyShortcut(next).isBindable else {
      return
    }
    combo = next
    onChange?(next)
    recording = false
    refresh()
  }

  override func flagsChanged(with event: NSEvent) {
    if recording {
      return
    }
    super.flagsChanged(with: event)
  }

  override func resignFirstResponder() -> Bool {
    cancelRecording()
    return super.resignFirstResponder()
  }
}

private let kVKEscape: Int = 53
private let kVKDelete: Int = 51
private let kVKForwardDelete: Int = 117

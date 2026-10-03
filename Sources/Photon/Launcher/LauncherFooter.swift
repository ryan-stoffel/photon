import PhotonCore
import SwiftUI

/// Bottom bar for every launcher view. Left: the Photon icon at root, the mode or clipboard
/// name, or an error or notice. Right: the primary action, then "Actions ⌘K" when there is more than one.
struct LauncherFooter: View {
  @ObservedObject var model: LauncherViewModel

  var body: some View {
    HStack(spacing: 10) {
      leading
      Spacer(minLength: 12)
      trailing
    }
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 14)
    .frame(height: LauncherLayout.footerHeight)
  }

  @ViewBuilder
  private var leading: some View {
    if let lastError = model.lastError {
      warning(lastError)
    } else if model.session == .clipboard, let clipboard = model.clipboard {
      if clipboard.isConfirmingClear {
        warning("Clear all \(clipboard.manager.items.count) items, including pinned ones?")
      } else if let notice = clipboard.notice {
        warning(notice.message)
        if notice.offersAccessibility {
          Button("Open Accessibility Settings") {
            clipboard.openAccessibilitySettings()
          }
          .buttonStyle(.link)
        }
      } else {
        Image(systemName: "clipboard")
          .font(.system(size: 12, weight: .medium))
        Text("Clipboard History")
          .fontWeight(.medium)
      }
    } else if let mode = model.activeMode {
      Text(mode.title)
        .fontWeight(.medium)
      if let notice = mode.notice {
        Text("\u{00B7}")
        Text(notice)
          .lineLimit(1)
      }
      if mode.isSearching {
        ProgressView()
          .controlSize(.small)
      }
    } else {
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 16, height: 16)
    }
  }

  @ViewBuilder
  private var trailing: some View {
    if model.session == .clipboard, model.clipboard?.isConfirmingClear == true {
      FooterKeyHint(label: "Confirm", keys: ["\u{21B5}"])
      FooterKeyHint(label: "Cancel", keys: ["esc"])
    } else {
      let actions = model.currentActions
      if let primary = actions.first {
        FooterKeyHint(label: primary.title, keys: ["\u{21B5}"])
      }
      if actions.count > 1 {
        Rectangle()
          .fill(Color.primary.opacity(0.15))
          .frame(width: 1, height: 14)
        FooterKeyHint(label: "Actions", keys: LauncherShortcut.actionPanel.glyphs)
          .contentShape(Rectangle())
          .onTapGesture {
            model.toggleActions()
          }
      }
    }
  }

  private func warning(_ message: String) -> some View {
    HStack(spacing: 8) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      Text(message)
        .foregroundStyle(.primary)
        .lineLimit(1)
        .truncationMode(.tail)
    }
  }
}

/// "Open ↵": the label first, then each key in a small cap.
struct FooterKeyHint: View {
  let label: String
  let keys: [String]

  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .padding(.trailing, 2)
      ForEach(keys, id: \.self) { key in
        Text(key)
          .font(.system(size: 11, weight: .semibold))
          .frame(minWidth: 14)
          .padding(.horizontal, 4)
          .padding(.vertical, 2)
          .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.primary.opacity(0.08)))
      }
    }
  }
}

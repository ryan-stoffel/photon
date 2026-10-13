import PhotonCore
import SwiftUI

/// Bottom bar for the command list and compact modes. Clipboard history and full-height modes draw
/// their own. Left: the Photon icon, the mode name, or an error. Right: the primary action, then
/// "Actions ⌘K" when there is more than one.
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
    } else if let mode = model.activeMode {
      Text(mode.title)
        .fontWeight(.medium)
    } else {
      Image(nsImage: PhotonAppIcon.current)
        .resizable()
        .interpolation(.high)
        .frame(width: 16, height: 16)
    }
  }

  @ViewBuilder
  private var trailing: some View {
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

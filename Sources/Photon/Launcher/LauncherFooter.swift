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
    .font(.system(size: 13))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 16)
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
        .frame(width: 18, height: 18)
    }
  }

  @ViewBuilder
  private var trailing: some View {
    let actions = model.currentActions
    if let primary = actions.first {
      FooterKeyHint(label: primary.title, keys: ["\u{21B5}"], emphasized: true)
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

/// "Open ↵": the label first, then each key in a small cap. The primary action's label is emphasized.
struct FooterKeyHint: View {
  let label: String
  let keys: [String]
  var emphasized = false

  var body: some View {
    HStack(spacing: 4) {
      Text(label)
        .fontWeight(emphasized ? .medium : .regular)
        .foregroundStyle(emphasized ? .primary : .secondary)
        .padding(.trailing, 4)
      ForEach(keys, id: \.self) { key in
        Text(key)
          .font(.system(size: 12, weight: .medium))
          .frame(minWidth: 20, minHeight: 20)
          .padding(.horizontal, 2)
          .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.08)))
      }
    }
  }
}

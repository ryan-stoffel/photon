import PhotonCore
import SwiftUI

extension LauncherViewModel {
  /// `currentActions` narrowed by the panel's filter text.
  var filteredActions: [LauncherAction] {
    let filter = actionQuery.trimmingCharacters(in: .whitespaces)
    let actions = currentActions
    guard !filter.isEmpty else {
      return actions
    }
    return actions.filter { FuzzyMatcher.matches(query: filter, candidate: $0.title) }
  }

  /// The highlighted panel row: `actionSelectedID`, or the first filtered action.
  var selectedAction: LauncherAction? {
    let actions = filteredActions
    return actions.first { $0.id == actionSelectedID } ?? actions.first
  }

  /// Panel header: the item the actions apply to.
  var actionPanelTitle: String {
    if let activeMode {
      return activeMode.title
    }
    if session == .clipboard {
      return clipboard?.selectedItem?.title ?? "Clipboard History"
    }
    return selectedRow?.title ?? ""
  }

  /// ⌘K. Opens with an empty filter on the first action; does nothing when there are no actions.
  func toggleActions() {
    if showsActions {
      showsActions = false
    } else if !currentActions.isEmpty {
      actionQuery = ""
      showsActions = true
    }
  }

  func moveActionSelection(_ delta: Int) {
    let actions = filteredActions
    guard !actions.isEmpty else {
      return
    }
    let index = actions.firstIndex { $0.id == selectedAction?.id } ?? 0
    actionSelectedID = actions[SelectionNavigation.moving(from: index, by: delta, count: actions.count)].id
  }
}

/// Raycast-style ⌘K panel: a floating list of the selection's actions above the footer,
/// with its filter field at the bottom. The launcher routes arrows, Return and Esc to it.
struct LauncherActionPanel: View {
  @ObservedObject var model: LauncherViewModel
  var onRun: (LauncherAction) -> Void
  @FocusState private var filterFocused: Bool

  private static let rowHeight: Double = 30

  var body: some View {
    let actions = model.filteredActions
    let selectedID = model.selectedAction?.id
    let primaryID = model.currentActions.first?.id
    // ponytail: no scroll view; every action list is under ten rows and fits the expanded panel.
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        LauncherSectionHeader(title: model.actionPanelTitle)
        if actions.isEmpty {
          Text("No actions")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .frame(height: Self.rowHeight)
        }
        ForEach(actions) { action in
          row(action, selected: action.id == selectedID, chips: action.shortcut?.glyphs ?? (
            action.id == primaryID ? ["\u{21B5}"] : []
          ))
        }
      }
      .padding(6)
      Rectangle()
        .fill(Color.primary.opacity(0.08))
        .frame(height: LauncherLayout.hairline)
      TextField("Search for actions\u{2026}", text: $model.actionQuery)
        .textFieldStyle(.plain)
        .font(.system(size: 13))
        .focused($filterFocused)
        .padding(.horizontal, 14)
        .frame(height: 36)
    }
    .frame(width: model.panelWidth / 2)
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.12), lineWidth: LauncherLayout.hairline)
    )
    .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
    .onAppear {
      filterFocused = true
    }
  }

  private func row(_ action: LauncherAction, selected: Bool, chips: [String]) -> some View {
    HStack(spacing: 10) {
      if let symbol = action.symbol {
        Image(systemName: symbol)
          .font(.system(size: 12, weight: .medium))
          .frame(width: 16)
      }
      Text(action.title)
        .font(.system(size: 13))
        .lineLimit(1)
      Spacer(minLength: 8)
      KeybindChipStack(chips: chips, emphasized: selected)
    }
    .foregroundStyle(action.isDestructive ? Color.red : Color.primary)
    .padding(.horizontal, 8)
    .frame(height: Self.rowHeight)
    .background(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(selected ? Color.primary.opacity(0.09) : Color.clear)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      onRun(action)
    }
  }
}

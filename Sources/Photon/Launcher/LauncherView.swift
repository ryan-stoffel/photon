import PhotonApps
import PhotonClipboard
import PhotonCore
import PhotonNotes
import SwiftUI

/// The launcher panel: search field, the command list (or a feature view), and a footer.
/// Sizes come from `LauncherLayout` so the AppKit window and this view always agree.
struct LauncherView: View {
  @ObservedObject var model: LauncherViewModel
  var onRun: () -> Void
  @EnvironmentObject private var settings: SettingsStore
  @EnvironmentObject private var runningApps: RunningApplications
  @FocusState private var searchFocused: Bool

  static let defaultPlaceholder = "Search apps, files, notes and more\u{2026}"

  var body: some View {
    VStack(spacing: 0) {
      searchField
      switch model.content {
      case .searchOnly:
        EmptyView()
      case .recommendations:
        Hairline(emphasized: true)
        resultsList
          .frame(height: LauncherLayout.expandedListHeight)
      case .rows:
        Hairline(emphasized: true)
        if model.session == .clipboard {
          LauncherClipboardResultsSection(model: model)
        } else {
          resultsList
        }
      case .fullHeight:
        Hairline(emphasized: true)
        featureContent
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      if showsPanelFooter {
        Hairline()
        if model.session == .clipboard, let clipboard = model.clipboard {
          ClipboardLauncherFooter(model: clipboard)
        } else if let mode = model.activeMode, model.content == .searchOnly {
          LauncherModeFooter(title: mode.title)
        } else {
          footer
        }
      }
    }
    .frame(width: model.panelWidth, height: LauncherLayout.height(for: model.content), alignment: .top)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .overlay(
      RoundedRectangle(cornerRadius: LauncherLayout.cornerRadius, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.1), lineWidth: LauncherLayout.hairline)
        .allowsHitTesting(false)
    )
    .onAppear {
      searchFocused = true
      runningApps.refresh()
      Task { await model.refresh() }
    }
    .onChange(of: model.focusGeneration) {
      searchFocused = true
    }
  }

  // MARK: Search field

  private var showsPanelFooter: Bool {
    model.showsCommandList
      || model.session == .clipboard
      || (model.activeMode != nil && model.content == .searchOnly)
  }

  private var searchField: some View {
    HStack(spacing: 12) {
      TextField(placeholder, text: $model.query)
        .textFieldStyle(.plain)
        .font(.system(size: 20))
        .focused($searchFocused)
        .allowsHitTesting(false)
        .onSubmit {
          Task { await run() }
        }
    }
    .padding(.horizontal, 20)
    .frame(height: LauncherLayout.searchFieldHeight)
    .contentShape(Rectangle())
  }

  private var placeholder: String {
    if model.session == .clipboard {
      "Search clipboard history\u{2026}"
    } else if let mode = model.activeMode {
      mode.placeholder
    } else {
      Self.defaultPlaceholder
    }
  }

  // MARK: Feature views (file search and other modes)

  @ViewBuilder
  private var featureContent: some View {
    if model.session == .clipboard {
      LauncherClipboardDetailSplitView(model: model)
    } else if let mode = model.activeMode {
      mode.makeResultsView()
    }
  }

  // MARK: Command list

  private var resultsList: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          if model.rows.isEmpty {
            messageRow
          } else {
            if let hero = model.calculatorHero {
              LauncherCalculatorHeroSection(
                model: hero,
                selected: model.selectedID == hero.commandID,
                onSelect: {
                  model.selectedID = hero.commandID
                }
              )
              .id(hero.commandID)
            }
            if !model.suggestionRows.isEmpty {
              suggestionHeader
            }
            ForEach(model.suggestionRows) { row in
              resultRow(row)
                .id(row.id)
            }
            ForEach(listRowsBelowSuggestions) { row in
              resultRow(row)
                .id(row.id)
            }
          }
        }
        .padding(.horizontal, 8)
        .padding(.top, model.calculatorHero != nil ? 0 : LauncherLayout.listInset)
        .padding(.bottom, LauncherLayout.listInset)
      }
      .onChange(of: model.selectedID) { _, newValue in
        if let newValue {
          proxy.scrollTo(newValue, anchor: .center)
        }
      }
    }
    .frame(maxHeight: .infinity)
  }

  /// Catalog rows under Suggestions. Typed queries keep the calculator hero out of this list.
  private var listRowsBelowSuggestions: [LauncherRow] {
    if model.suggestionCount > 0 {
      return model.rowsAfterSuggestions
    }
    return model.rowsBelowCalculatorHero
  }

  private var suggestionHeader: some View {
    Text("Suggestions")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 12)
      .padding(.top, 2)
      .padding(.bottom, 2)
      .accessibilityAddTraits(.isHeader)
  }

  private var messageRow: some View {
    HStack {
      Text(model.isLoading ? "Indexing applications\u{2026}" : "No results")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
      Spacer()
    }
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.rowHeight)
  }

  private func resultRow(_ row: LauncherRow) -> some View {
    let selected = row.id == model.selectedID
    let chips = shortcutChips(for: row)
    return HStack(spacing: 12) {
      runningAppIcon(for: row)
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(row.title)
          .font(.system(size: 14, weight: .medium))
          .lineLimit(1)
          .layoutPriority(1)
        if let detail = row.detail {
          Text(detail)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.middle)
        }
      }
      Spacer(minLength: 8)
      if !chips.isEmpty {
        KeybindChipStack(chips: chips, emphasized: selected)
      }
    }
    .padding(.horizontal, 10)
    .frame(height: LauncherLayout.rowHeight)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(selected ? Color.primary.opacity(0.09) : Color.clear)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      model.selectedID = row.id
      Task { await run() }
    }
  }

  private func runningAppIcon(for row: LauncherRow) -> some View {
    let running = row.showsRunningIndicator(runningBundleIDs: runningApps.bundleIdentifiers)
    return ZStack(alignment: .bottom) {
      rowIcon(for: row)
        .frame(width: LauncherLayout.iconSize, height: LauncherLayout.iconSize)
      if running {
        Circle()
          .fill(Color.primary.opacity(0.78))
          .frame(width: 4, height: 4)
          .offset(y: 3)
          .accessibilityLabel("Running")
      }
    }
    .frame(width: LauncherLayout.iconSize, height: LauncherLayout.iconSize)
  }

  private func shortcutChips(for row: LauncherRow) -> [String] {
    LauncherRowChrome.shortcutChips(
      commandID: row.id,
      keybinds: settings.keybinds,
      clipboardHotkeyEnabled: settings.clipboardHotkeyEnabled,
      clipboardHotkey: settings.clipboardHotkey,
      notesHotkey: settings.notesHotkey
    )
  }

  @ViewBuilder
  private func rowIcon(for row: LauncherRow) -> some View {
    switch CommandIconCache.shared.resolve(row.icon, fallbackSymbol: symbolName(forProvider: row.providerID)) {
    case let .image(image):
      Image(nsImage: image)
        .resizable()
        .interpolation(.high)
        .frame(width: LauncherLayout.iconSize, height: LauncherLayout.iconSize)
    case let .symbol(name):
      symbolTile(name)
    }
  }

  /// Commands without an app icon get a quiet tile so every row lines up.
  private func symbolTile(_ name: String) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 7, style: .continuous)
        .fill(Color.primary.opacity(0.08))
      Image(systemName: name)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .frame(width: LauncherLayout.iconSize - 2, height: LauncherLayout.iconSize - 2)
  }

  private func symbolName(forProvider providerID: String) -> String {
    switch providerID {
    case "apps": "app.fill"
    case "clipboard": "clipboard"
    case "files": "doc"
    case "notes": "note.text"
    case "calculator": "function"
    default: "circle.grid.3x3"
    }
  }

  // MARK: Footer

  private var footer: some View {
    HStack(spacing: 12) {
      if let lastError = model.lastError {
        Image(systemName: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
        Text(lastError)
          .lineLimit(1)
          .truncationMode(.tail)
      } else {
        Image(nsImage: PhotonAppIcon.current)
          .resizable()
          .interpolation(.high)
          .frame(width: 16, height: 16)
        Text("Photon")
          .fontWeight(.medium)
      }
      Spacer(minLength: 12)
      if let row = model.selectedRow {
        FooterKeyHint(label: row.actionVerb, key: "\u{21B5}")
      }
    }
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 14)
    .frame(height: LauncherLayout.footerHeight)
  }

  private func run() async {
    switch model.session {
    case .clipboard:
      await model.clipboard?.performPrimaryAction()
    case .commands:
      if await model.runSelection() {
        onRun()
      }
    }
  }
}

/// One-point separator. The hairline under the search field is slightly darker on top.
private struct Hairline: View {
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

/// Compact-mode label in the footer corner (Clipboard / Files). No search-field pill.
private struct LauncherModeFooter: View {
  let title: String

  var body: some View {
    HStack(spacing: 12) {
      Text(title)
        .fontWeight(.medium)
      Spacer(minLength: 0)
    }
    .font(.system(size: 12))
    .foregroundStyle(.secondary)
    .padding(.horizontal, 14)
    .frame(height: LauncherLayout.footerHeight)
  }
}

/// Trailing Raycast-style keycaps for an assigned shortcut.
private struct KeybindChipStack: View {
  let chips: [String]
  var emphasized = false

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
        Text(chip)
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(.primary.opacity(0.86))
          .frame(minWidth: 18, minHeight: 18)
          .padding(.horizontal, 5)
          .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
              .fill(Color.primary.opacity(emphasized ? 0.14 : 0.08))
          )
      }
    }
    .accessibilityLabel(chips.joined(separator: " "))
  }
}

/// "Open ↵": the label first, then the key in a small cap.
private struct FooterKeyHint: View {
  let label: String
  let key: String

  var body: some View {
    HStack(spacing: 6) {
      Text(label)
      Text(key)
        .font(.system(size: 11, weight: .semibold))
        .frame(minWidth: 14)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(RoundedRectangle(cornerRadius: 4, style: .continuous).fill(Color.primary.opacity(0.08)))
    }
  }
}

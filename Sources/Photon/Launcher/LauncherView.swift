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
  /// Runs a ⌘K panel action through the controller, the same path as its keyboard shortcut.
  var onAction: (LauncherAction) -> Void
  @EnvironmentObject private var settings: SettingsStore
  @EnvironmentObject private var runningApps: RunningApplications
  @FocusState private var searchFocused: Bool

  static let defaultPlaceholder = "Search for apps and commands\u{2026}"
  /// Zero-height marker at the top of the list. Selecting the first row scrolls here so its header shows.
  private static let listTopID = "launcher.list.top"

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
            .frame(height: resultsListHeight)
        }
      case .fullHeight:
        Hairline(emphasized: true)
        featureContent
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      // Clipboard history and full-height modes (Files) draw their own footer.
      if model.session == .clipboard, let clipboard = model.clipboard {
        Hairline()
        ClipboardLauncherFooter(model: clipboard)
      } else if model.activeMode == nil || model.content == .searchOnly {
        Hairline()
        LauncherFooter(model: model)
      }
    }
    .frame(width: model.panelWidth, height: LauncherLayout.height(for: model.content), alignment: .top)
    .overlay(alignment: .bottomTrailing) {
      if model.showsActions {
        LauncherActionPanel(model: model, onRun: onAction)
          .padding(.trailing, 8)
          .padding(.bottom, LauncherLayout.footerHeight + LauncherLayout.hairline + 6)
      }
    }
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
    .onChange(of: model.showsActions) { _, shows in
      if !shows {
        searchFocused = true
      }
    }
  }

  // MARK: Search field

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
      "Type to filter entries\u{2026}"
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
          Color.clear
            .frame(height: 0)
            .id(Self.listTopID)
          if model.rows.isEmpty {
            messageRow
          } else {
            if let hero = model.calculatorHero {
              LauncherCalculatorHeroSection(
                model: hero,
                selected: model.selectedID == hero.commandID,
                onSelect: {
                  model.selectedID = hero.commandID
                },
                onActivate: {
                  model.selectedID = hero.commandID
                  Task { await run() }
                }
              )
              .id(hero.commandID)
            }
            if !model.suggestionRows.isEmpty {
              LauncherSectionHeader(title: "Suggestions")
            }
            ForEach(model.suggestionRows) { row in
              resultRow(row)
                .id(row.id)
            }
            if !listRowsBelowSuggestions.isEmpty {
              LauncherSectionHeader(title: listHeaderTitle)
            }
            ForEach(listRowsBelowSuggestions) { row in
              resultRow(row)
                .id(row.id)
            }
          }
        }
        .padding(.horizontal, 8)
        .padding(.top, model.calculatorHero != nil ? 0 : LauncherLayout.listInset)
        .padding(
          .bottom,
          model.calculatorHero != nil && listRowsBelowSuggestions.isEmpty ? 0 : LauncherLayout.listInset
        )
      }
      .onChange(of: model.selectedID) { _, newValue in
        guard let newValue else {
          return
        }
        // Scroll only as far as needed. The first row also reveals the header above it.
        if newValue == model.results.first?.id {
          proxy.scrollTo(Self.listTopID, anchor: .top)
        } else {
          proxy.scrollTo(newValue)
        }
      }
    }
  }

  /// Visible list height. A flexible max height lets the scroll view fill a stale
  /// expanded panel and leave a gap between the last row and the footer.
  private var resultsListHeight: Double {
    LauncherLayout.listHeight(
      rowCount: model.rows.count,
      showsCalculatorHero: model.calculatorHero != nil
    )
  }

  /// Catalog rows under Suggestions. Typed queries keep the calculator hero out of this list.
  private var listRowsBelowSuggestions: [LauncherRow] {
    if model.suggestionCount > 0 {
      return model.rowsAfterSuggestions
    }
    return model.rowsBelowCalculatorHero
  }

  /// "Commands" under Suggestions, "Results" for a typed query, or the fallback header.
  private var listHeaderTitle: String {
    if model.query.isEmpty {
      return "Commands"
    }
    if model.showsFallbacks {
      return "Use \u{201C}\(model.query.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D} with\u{2026}"
    }
    return "Results"
  }

  private var messageRow: some View {
    HStack {
      Text(model.isLoading ? "" : "No results")
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
        if !chips.isEmpty {
          KeybindChipStack(chips: chips, emphasized: selected)
        }
      }
      Spacer(minLength: 8)
      if let accessory = row.accessory {
        Text(accessory)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .fixedSize()
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
      // A click outside the open ⌘K panel only closes it.
      if model.showsActions {
        model.showsActions = false
        return
      }
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
      clipboardHotkeyEnabled: settings.clipboardEnabled && settings.clipboardHotkeyEnabled,
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

/// List section title ("Suggestions", "Results", "Calculator"), bottom-aligned in `sectionHeaderHeight`.
struct LauncherSectionHeader: View {
  let title: String

  var body: some View {
    Text(title)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.secondary)
      .lineLimit(1)
      .padding(.horizontal, 12)
      .padding(.bottom, 2)
      .frame(maxWidth: .infinity, alignment: .leading)
      .frame(height: LauncherLayout.sectionHeaderHeight, alignment: .bottom)
      .accessibilityAddTraits(.isHeader)
  }
}

/// Raycast-style keycaps for a shortcut.
struct KeybindChipStack: View {
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

# Photon architecture

Photon is a Swift 6 menu-bar agent (`LSUIElement`, bundle id `com.ryanstoffel.photon`) built with SwiftPM. There is no committed Xcode project. `Scripts/package_app.sh` wraps the `Photon` executable in `Photon.app`. `Scripts/package_app.sh --dev` (or `PHOTON_DEV=1`) writes `build/Photon-Dev.app` with bundle id `com.ryanstoffel.photon.dev` and a yellow "dev" tag on the icon, so it can run beside the release app. The default command stays the release bundle.

Deployment target: macOS 14+. Newer materials (`NSGlassEffectView` / Liquid Glass) are used at runtime when the class exists; GitHub Actions `macos-latest` logs `sw_vers` and the SDK in the `lint` and `smoke` jobs. See [macos-runners.md](macos-runners.md).

## Module layout

```
Sources/
  PhotonCore/           Fuzzy matching, frecency, Command, CommandRegistry, launcher layout and row rules
  Photon/               App process: hotkey, launcher panel, settings, wiring
  PhotonApps/           Application + System Settings pane provider
  PhotonClipboard/      Clipboard history: monitor, store, search, panel view
  PhotonNotes/          Floating markdown notes (see below)
  PhotonFiles/          Spotlight/`mdfind` file search: provider, launcher file mode, Quick Look
  PhotonKeybinds/       Hyper key, app hotkeys, window management
  PhotonCalculator/     Inline launcher calculator and unit conversions
Tests/
  PhotonCoreTests/      FuzzyMatcher, FrecencyStore, Command icons, launcher layout, selection navigation
  PhotonAppsTests/      App names, System Settings pane titles and aliases, index dedupe, pane icon policy
  PhotonClipboardTests/ History rules (dedupe, retention), search ranking, store round trip
  PhotonNotesTests/     Title extraction, markdown spans, store, debounce, query parsing, notes layout
  PhotonFilesTests/     Spotlight query strings, mdfind args, ranking, path truncation
  PhotonKeybindsTests/  Frame math, shortcut parsing, conflicts, hidutil mapping format
```

`Package.swift` only adds the AppKit modules and the `Photon` executable when `os(macOS)` is true. `PhotonCore` compiles everywhere. `PhotonClipboard` is also declared for every platform: its AppKit files are wrapped in `#if canImport(AppKit)`, so the models, history rules, search, and store build and test on Linux while the monitor, paster, and views only compile on macOS.

| Module | Depends on | Imports AppKit? |
| --- | --- | --- |
| PhotonCore | -- | no |
| PhotonApps | PhotonCore | yes |
| PhotonClipboard | PhotonCore | partly (guarded) |
| PhotonNotes | PhotonCore | yes (AppKit panel, SwiftUI overlays) |
| PhotonFiles | PhotonCore | yes (plus QuickLookUI) |
| PhotonKeybinds | PhotonCore | yes (plus ApplicationServices, CoreGraphics, IOKit) |
| PhotonCalculator | PhotonCore | partly (pasteboard copy guarded) |
| Photon | all of the above | yes |

## How a provider plugs in

A provider is a `CommandProvider`:

```swift
public protocol CommandProvider: Sendable {
  var id: String { get }
  var displayName: String { get }
  func reload() async
  func commands(matching query: String) async -> [Command]
  func execute(_ command: Command) async throws
}
```

`Command` is a value type (`id`, `title`, `subtitle`, `keywords`, `providerID`, optional `icon`). Providers own how they find and run things. The launcher only searches and dispatches.

`icon` is a `CommandIcon`: the Finder icon of a path (`.fileIcon`), an image file (`.imageFile`), an application by bundle id (`.application`), a named image in a bundle or its asset catalog (`.bundleResource`), or an SF Symbol (`.symbol`). It stays a plain value so `PhotonCore` needs no AppKit; `Sources/Photon/Launcher/CommandIconCache.swift` resolves and caches the `NSImage`s (`NSWorkspace.icon(forFile:)`, `NSImage(contentsOfFile:)`, `urlForApplication(withBundleIdentifier:)`) and is warmed in the background once the providers have loaded. Apps use their bundle's Finder icon. Built-in System Settings panes are Settings extensions (`.appex`) under `/System/Library/ExtensionKit/Extensions`, opened by `x-apple.systempreferences` URL and drawn with their own icon, or with the System Settings icon when they declare none. Third-party `.prefPane` panes go through `PaneIconPolicy` (`PhotonApps`), which reads the pane's declared icon (`NSPrefPaneIconFile`, `CFBundleIconFile`, or an asset catalog entry) and falls back to the System Settings app icon.

To add a Phase 2 feature:

1. Put the implementation in that feature's module (`Sources/PhotonNotes/`, …). Do not grow `PhotonApps` or dump logic into `PhotonCore`.
2. Conform to `CommandProvider`. Use `FuzzyMatcher` and `FrecencyStore` from PhotonCore if the feature is searchable.
3. Register the provider in `Sources/Photon/AppRuntime.swift` only:

   ```swift
   registry.register(NotesProvider())
   ```

4. Bind settings for that feature to `SettingsStore` and replace the placeholder tab in `SettingsRootView`. Leave other tabs alone.

The registry is a list. Search asks every provider for `commands(matching:)`. A typed query ranks an exact title first, then an exact keyword, then a fuzzy title match (`FuzzyMatcher`), then a fuzzy keyword match. `FrecencyStore` adds at most 0.2, so it only breaks near-ties. Enter calls `execute` on the provider that owns the selected command, then records the id in frecency. An empty query orders by raw frecency and ranks Suggestions by local use count for applications and standing commands (Clipboard History, Search Files, Notes, window layouts). File hits, individual notes, and Settings panes stay in the catalog underneath. Typed queries then place a matching application ahead of Search Files, and filename hits trail every other result (at most `trailingLimit`, 5). A typed query with no matches lists Search Files under a `Use "<query>" with…` header, and running it opens Files with that query.

Shared files that every feature touches today:

- `Sources/Photon/AppRuntime.swift` — one `register` line
- `Sources/Photon/Settings/SettingsStore.swift` — new `@AppStorage` keys if needed
- `Sources/Photon/Settings/SettingsRootView.swift` — swap a placeholder tab

Avoid editing `Command.swift` or `CommandRegistry.swift` unless the protocol itself is insufficient. Prefer a new file in your module.

### Launcher sessions and modes

Clipboard history is a `LauncherSession.clipboard` beside the command list: same search field, its own view model, prefix (`cb ` / `clipboard `), and keys. File search uses a generic `LauncherMode` protocol (`Sources/Photon/Launcher/LauncherMode.swift`): typed prefixes (`/`, `f `), an activation command id, and optional inline results after the primary list. While a mode is active the launcher renders `makeResultsView()` and forwards leftover keys to `handle(_:)`. Esc clears typed text first, then leaves the mode or clipboard session, then hides the launcher. A fresh Backspace on an empty query also leaves. A held Backspace does not. ⌃N/⌃P and Page Up/Down move in every list, and a new query selects the first row. A mode reaches back through `LauncherModeHost` (focus, dismiss, activate the app for an auxiliary panel).

`⌘K` opens a Raycast-style action panel at the bottom right (`LauncherActionPanel`) with a filter field. Arrows move, Return runs, and Esc closes it. The panel closes when the query or the selection changes. Its rows are `LauncherAction` values from `LauncherViewModel.currentActions`: the active mode's `actions()`, `clipboardActions()`, or `rootActions()` for the selected root row. `LauncherAction.swift` documents the rules. `actions[0]` is the Return action and has no shortcut. Every other shortcut includes ⌘ or ⌃ and runs while the launcher is key, whether or not the panel is open. App rows add Show in Finder ⌘↵, Copy Path ⌥⌘C, Copy Name, Copy Bundle Identifier, and Quit Application while the app runs. File rows offer Open, Show in Finder ⌘↵, and Copy Path ⌥⌘C. Command, pane, note, and app rows add Reset Ranking. The calculator offers Copy Answer. `LauncherMode.selectionTitle` is the panel header. A compact or short panel grows while the action panel is open. `LauncherFooter` is the footer for the command list and compact modes: the Photon icon or the mode name on the left, `<primary> ↵ | Actions ⌘K` on the right, with Actions only when there is more than one action. Clipboard history (`ClipboardLauncherFooter`) and full-height modes such as Files draw their own footer.

Register a mode next to the provider: `launcher.register(mode:)`. Clipboard still uses `attachClipboard` rather than this hook; a chore issue tracks unifying the two.

## File search (PhotonFiles)

Pipeline, all off the main thread except the final publish:

1. `SpotlightQueryBuilder` turns the typed text into a raw Spotlight query string (`kMDItemDisplayName == "*term*"cd || kMDItemFSName == ...`; every alphanumeric term must match; underscores and punctuation split terms so `ember_individual` is `ember` AND `individual`; terms shorter than three characters only match word prefixes; `kMDItemTextContent` is added when "search file contents" is on). Every query adds `kMDItemSupportFileType != "MDSystemFile"`, so Spotlight's system support files, such as app data under `~/Library`, never match.
2. `FileSearchEngine` (main actor) debounces 120 ms, cancels the in-flight query, and runs `MdfindQueryRunner`: `/usr/bin/mdfind -onlyin $HOME` (plus extra folders; omitted for **This Mac**) with `-0` null-terminated paths, once for the metadata query and once per term of three or more characters as a `kMDItemFSName` substring query. The runner drains stdout while `mdfind` runs, so broad queries do not stall. Up to `max(500, 20 x limit)` hits become `FileResult` values via `FileResultFactory`. With content search on, files that only match by text rank below every name match. Empty Files lists files used in the last 30 days (`kMDItemLastUsedDate`), newest first, minus excluded folders. This is the same Spotlight/`mdfind` path Raycast uses; the engine does not walk the filesystem.
3. `FileRanker` scores name relevance (exact > prefix > word start > substring > file name > content), drops user-excluded folders and blocked system paths (`/System`, `/Library` except `~/Library`, `/private`, `/usr`, `/bin`) after resolving `/System/Volumes/Data` firmlinks, dedupes, sorts by relevance, last-used, modified, name, and caps at the configured limit. `FileIconCache` prefetches Finder icons before results are published so rows never pop.
4. `FileSearchController` publishes results and owns selection, Quick Look (`QuickLookCoordinator`, `QLPreviewPanel` data source found through the launcher panel's responder chain; ↑/↓ move the selection and ⌘Y closes it while the panel is key), and actions (`FileActions`: open, show in Finder, copy path). `FileSearchMode.actions()` exposes them as `LauncherAction`s: the Settings > Files Enter action, the other one (⌘↵), Quick Look (⌘Y), and Copy Path (⌥⌘C). Empty Files mode stays a compact search field until the user types. `FileSearchView` renders rows (icon, name, the parent path only when it fits, kind), the detail pane, and its own footer: "Files", any notice and the refresh spinner, then `<Enter action> ↵ | Actions ⌘K` while a file is selected.

`FilesProvider` contributes the *Search Files* command and, for queries of three or more characters, filename matches that trail the other results in the root list (at most `trailingLimit`, 5). The launcher never switches into Files mode on its own. Enter on an inline row reads the file from disk. It never blocks `CommandRegistry.search`: it returns what is cached for the exact query and otherwise starts a background search that asks the launcher to refresh when it finishes.

Spotlight privacy exclusions apply automatically because Spotlight never indexes them. Default scope is the user home folder (`mdfind -onlyin $HOME`); **This Mac** remains available in settings. `FileRanker` re-sorts Spotlight hits with launcher-style fuzzy matching on the stem, file name, and path relative to home (separator-insensitive). Paths shown in the UI abbreviate firmlink prefixes (`/System/Volumes/Data/...`) to `~/…`. The Files settings tab (`FilesSettingsView`, bound to `SettingsStore.files*` keys and bridged to `FileSearchSettings` by `FileSearchIntegration`) adds scope, content search, result limit, default action, inline results, extra folders, and excluded folders.

## PhotonNotes

Raycast-Notes-style floating notes. One markdown file per note in
`~/Library/Application Support/Photon/Notes/` (`Photon-Dev/Notes/` for the dev bundle); the first non-blank line is the title. No cloud, no accounts.

| Type | Role |
| --- | --- |
| `NotesController` (public) | Facade the app uses: show / toggle / hide, create, open, delete, preferences, `noteSummaries()` for the launcher. Owns the store, the current note, and autosave. |
| `NoteStore` | Directory-backed CRUD. Files are named after creation time (`Note 2026-09-14 at 03.12.45.md`) and never renamed, so launcher frecency stays stable. Writes are atomic; `rescan()` diffs modification date + size so external edits are picked up when the window becomes key. Delete moves to the Trash. |
| `NotesWindow` / `NotesPanel` | Non-activating vibrancy `NSPanel` (titled, closable, resizable, transparent titlebar). Width is fixed at 680 pt (`NotesLayout`); height is user-resizable. HUD material sits behind a clear markdown editor, a character-count footer, and a **T** format control. Overlays: notes switcher (⌘P, with Pinned and Notes sections, ⇧⌘P pin, ⌃X delete, ⌘1–9 open pinned notes), actions palette (⌘K), and the format bar, a bottom strip that keeps editor focus. Deeplinks are `photon://note/<id>`. Frame autosave `PhotonNotesWindow.v039`. |
| `NotesWindow+Toolbar` | Trailing toolbar: command palette (`command`), browse notes (`list.bullet.rectangle`), new note (`plus`). |
| `MarkdownFormat` / `NoteAction` | Pure edits for headings, emphasis, code blocks, quotes, lists, links, and list-item move. Emphasis, the same heading level, lists, and quotes toggle off, and list and quote formats apply to every selected line. `NotesWindow+Shortcuts` maps Raycast's format chords onto them, and each edit is one undo step. ⌘K catalog (New / Duplicate / Browse / Find / Copy / Deeplink / Export / Move List Item / Format ⌥⌘, / Zoom In, Out, Reset / Delete Note ⌃X). |
| `MarkdownTextView` + `MarkdownTextStyler` | `NSTextView` (TextKit 1, plain text) styled from `MarkdownStyler` spans inside `NSTextStorageDelegate.didProcessEditing` (`NotesWindow+Editor.swift`). Content stays plain markdown; only attributes change. The first non-blank line gets the `.title` look (1.7× the body size, bold, extra paragraph spacing) layered over its markdown spans. 18 pt container insets. Clicking `[ ]` or ⌘↵ toggles it, Return continues lists. |
| `MarkdownStyler` (pure) | Line-based span computation: headings, bold / italic, inline code, fenced code, bullet and numbered lists, checkboxes, quote lines, and `[label](url)` links. `titleSpan(in:)` marks the first non-blank line; `editAffectsTitle(_:in:)` tells the editor when an edit near the top needs a full pass. Otherwise restyling is paragraph-local unless the document contains a fence. |
| `NoteSidebarRow` (pure) / `NoteSidebarModel` / `NoteSidebarView` | Sidebar rows (title, snippet or "No additional text", Notes-style date: time today, "Yesterday", weekday within a week, else numeric) sorted newest first; the model bridges the SwiftUI `List(selection:)` to the controller and distinguishes user selection from programmatic updates. |
| `Debouncer` (pure) | Autosave coalescing (0.6 s) with an injectable scheduler for tests. Flushes on note switch, hide, resign key, and termination. |
| `NoteQuery` (pure) | Launcher grammar: `notes`, `note`, `n <text>`, `note <text>`, `notes <text>` list notes; anything else only matches the fixed "Notes", "Create Note" and "Search Notes" commands. |
| `NotesProvider` | `CommandProvider`: `notes.open`, `notes.new`, `notes.search` (opens the switcher), and `note:<id>` results. |

App-side wiring lives in `Sources/Photon/Notes/NotesIntegration.swift`: it maps `SettingsStore` (font size, float, open on launch, optional hotkey) onto `NotesPreferences`, registers the toggle hotkey as `HotkeyManager.HotkeyID.notes` (id 3), and exposes the provider that `AppRuntime` registers. `HotkeyManager` supports several hotkeys keyed by id; the launcher keeps id 1 and the original `register(combo:)` / `onPressed` API.

## Process shape

- `PhotonApp` is a SwiftUI `@main` app with `NSApplicationDelegateAdaptor`.
- `LSUIElement` plus an explicit `.accessory` activation policy keep it out of the Dock. `StatusItemController` owns the `NSStatusItem` and its launcher, clipboard, notes, settings, and quit menu.
- `HotkeyManager` wraps Carbon `RegisterEventHotKey`. The default shortcut is `Cmd+Space`. `SpotlightConflict` compares that shortcut to Spotlight (`com.apple.symbolichotkeys`, id 64). When they collide, the welcome itself shows "Spotlight uses this shortcut." and an Open Keyboard Settings button, counting a missing plist entry as Spotlight's stock ⌘Space. The separate conflict alert only runs on launches where the welcome was already seen.
- The first-run note is one window (`WelcomeWindow`) on the active space, using the launcher's Liquid Glass or vibrancy and 12 pt continuous corners. It shows the app icon, the name Photon, and the configured launcher shortcut (`settings.hotkey`, falling back to `HotkeyCombo.defaultCombo`). Grant Access asks for Accessibility, then Input Monitoring, and waits until each system dialog is answered before showing the next. Escape or the close button dismisses it without prompting. There is no dim, beam, flash, or star field. `hasSeenMinimalWelcome` gates it, so it is first launch only. Settings > General > Show again replays it. The parity harness marks the welcome seen and dismisses it before launcher hide and focus checks, then opens the window and dismisses it without clicking Grant Access. Sora stays under `Resources/Fonts` and is not drawn here.
- `LauncherPanelController` owns a non-activating floating `NSPanel`. Its content view is Liquid Glass (`NSGlassEffectView`) when that class exists, otherwise an `NSVisualEffectView` (`.popover`, `.behindWindow`, always active) clipped to a 12 pt continuous corner radius, with the SwiftUI `LauncherView` on top. The panel is created at launch so the hotkey only has to order it front, on the screen under the mouse. Esc and ⌘W hide it. Losing key focus hides it without restoring the previous app, and like a hotkey toggle it keeps the view and query, which `show()` restores within 90 s (pop to root, `LauncherPanelController+PopToRoot.swift`). Clipboard paste returns to a note or Settings window that was key before the launcher opened, and only calls `NSApp.hide` when Photon is active. Running a command hides Photon first and does **not** restore the previous app, so `ForegroundActivation` can bring the target above everything (`yieldActivation` plus `activateIgnoringOtherApps`). The panel has a command list, a clipboard session (`LauncherSession.clipboard`), and protocol-based feature modes (`LauncherMode`; file search today).
- Panel size: `LauncherLayout` (PhotonCore) is the single source of the metrics (56 pt search field, 40 pt rows, 10 visible, 32 pt footer, width presets 620 / 760 / 860). Empty-query recommendations keep the 760×502 frame and scroll the full catalog; Down/Up clamp instead of wrapping. A Suggestions section lists applications and standing commands by local open count (`LauncherRanking`); file hits, individual notes, and Settings panes stay in the catalog under that prefix. Running dots stay on open regular (Dock) apps wherever they sit. Lists show "Suggestions", "Commands", and "Results" section headers and scroll only at the edges. `LauncherViewModel` publishes a `LauncherContent` (`.searchOnly` for an empty query in compact mode, `.recommendations` for the Down-to-reveal list, `.rows(n)` for typed results, or `.fullHeight` for clipboard history, expanded file search, and other `LauncherMode` views); the controller resizes the window from it with the top edge fixed (unless the taller panel would leave the visible frame), and `LauncherView` sizes itself from the same value, so the two never disagree. Click-and-drag anywhere on the panel repositions it after a small slop so row and button clicks still work. Live drag tracks `NSEvent.mouseLocation` in screen space so the window follows the pointer; dotted snap guides sit on the panel's left and right edges when it is centred. The panel snaps to center when its midpoint is inside the snap corridor: half the panel width to each side of center, or a quarter of the free width on screens narrower than three panel widths. The stored position is relative to the screen's visible frame and is clamped on resize. Positions saved by 0.4.8 and earlier reset once. Files and clipboard detail panes reserve a footer-safe inset so metadata cannot paint over shortcuts. `LauncherRow` maps a `Command` to what a row shows (title, optional secondary detail, icon, and a right-aligned type label: Application, File, Note, or Command). Settings > Appearance (`launcherShowsSuggestions`, `launcherPanelWidth`, `appearance`) reach the launcher as a `LauncherPreferences` value; `appearance` is applied to `NSApp.appearance`.
- `HotkeyManager` registers several Carbon hotkeys keyed by id: `1` is the launcher, `2` opens clipboard history, `3` toggles the notes window (off by default), and `add(combo:handler:)` hands out ids from `1000` for features with a dynamic number of shortcuts (app hotkeys, window commands).
- Settings is a Photon-styled window: the same Liquid Glass / vibrancy panel chrome, 12 pt continuous corners, and type as the launcher (not a System Settings clone). Sidebar rows match launcher selection chrome. `⌘,` is wired through the Photon menu, the status item, and a local key monitor so it works while the launcher is key. The main menu also has Edit (Undo, Redo, Cut, Copy, Paste, Select All) and Window (Close ⌘W, Minimize ⌘M) with nil targets, so they reach whichever Photon window is key. SIGTERM and SIGINT quit through `NSApp.terminate`, so `applicationWillTerminate` still removes the Hyper key remap. Each pane adds its own focus ids, so Tab follows the pane's layout. Panes: General, Appearance, Clipboard, Notes, Files, Keybinds, About. Keybinds lists installed and running apps for shortcut assignment. `PHOTON_DEBUG=1` enables cheap `PhotonTiming` logs for launcher show/search and Files search.

## Clipboard history (`PhotonClipboard`)

| Piece | Role |
| --- | --- |
| `ClipboardItem`, `ClipboardCapture`, `ClipboardSettings` | Value types. An item has a primary kind (`text`, `link`, `image`, `file`) plus optional secondary representations (RTF next to text, an image rendition next to text). |
| `ClipboardHistory` | Pure rules: newest first, duplicates collapse into one entry that moves to the top (by FNV-1a content hash), `prune` drops expired unpinned items then the oldest unpinned items over the limit. Pinned items never expire. |
| `ClipboardSearch` | Ranking for the clipboard view: every token must match title, body, file paths, source app, or kind; exact title hits outrank body hits, which outrank fuzzy hits; small recency and pinned bonuses. Empty query lists pinned first. |
| `ClipboardStore` | Actor. `index.json` (Codable `[ClipboardItem]`) plus `blobs/<uuid>.txt|.rtf|.png` under `~/Library/Application Support/Photon/Clipboard/` (`Photon-Dev/Clipboard/` for the dev bundle). Text up to 16 KB is inline; longer text and all images/RTF are blobs. An `index.json` that fails to decode is moved to `index.unreadable-<unix time>.json` instead of being overwritten, and Clear History deletes those backups. A capture whose blobs fail to write is not stored. No third-party dependencies. |
| `PasteboardMonitor` | Polls `NSPasteboard.general.changeCount` every 0.3 s on a utility queue. Skips `org.nspasteboard.ConcealedType` / `TransientType`, excluded frontmost apps, and Photon's own writes. |
| `ClipboardPaster` | Writes an item back (string, URL, RTF, PNG, or file URLs) and sends `Cmd+V` via `CGEvent` when `AXIsProcessTrusted()`. |
| `ClipboardManager` | `@MainActor` façade: publishes items and storage size, applies settings, paste/copy, pin, delete, clear. |
| `ClipboardProvider` | The launcher command "Clipboard History" and the `cb ` / `clipboard ` prefix. Running it switches the panel into clipboard mode instead of closing it. |
| `ClipboardHistoryViewModel` / `ClipboardLauncherRow` / `ClipboardLauncherFooter` | Clipboard mode in the launcher. With any history it opens expanded on the first entry, with launcher-style rows (type icon, snippet, relative time) and the detail pane. An empty query with pins shows Pinned and Recent sections. Return runs the Primary Action setting (Paste to Active App or Copy to Clipboard) and ⌘↵ runs the other one. ⇧⌘P pins, ⌃X deletes, and ⌃⇧X deletes all after an inline confirmation. These are `LauncherAction`s from `clipboardActions()` (`Sources/Photon/Launcher/LauncherClipboardActions.swift`), listed in the ⌘K panel. The footer reads "Clipboard History", then `<primary> ↵ | Actions ⌘K` while an entry is selected. Esc clears the filter, then goes back. |

`AppRuntime` creates one `ClipboardManager`, hands it to `LauncherPanelController.attachClipboard`, registers the provider, and mirrors `SettingsStore` into `ClipboardSettings` through `onClipboardChange`. The Clipboard settings tab (`ClipboardSettingsView`) binds to `SettingsStore` and reads storage size from the manager.

## PhotonKeybinds

`KeybindsController` (`@MainActor`, an `ObservableObject` the Keybinds tab observes) owns everything and is driven by one value, `KeybindsConfiguration`, which `SettingsStore` persists as JSON (`keybindsConfiguration`). `apply(_:)` is idempotent and runs after every settings change.

| Piece | Role |
| --- | --- |
| `KeyShortcut` / `KeyModifiers` | Key code + modifiers. `⌃⌥⇧⌘` together is the Hyper key (`isHyper`, shown as `✦`). Parses `hyper+left`, `cmd+shift+k`, `⌃⌥⇧⌘Return`; converts to Carbon and `CGEventFlags` masks. Pure. |
| `WindowAction` / `WindowLayout` | The 19 window commands and their frame math (grid cells, translate between displays, fit, screen lookup, coordinate flip). A repeated Left/Right/Top/Bottom Half cycles ½ → ⅔ → ⅓. Pure, bottom-left coordinates. |
| `KeybindsConfiguration` | Hyper key settings, app hotkeys, window bindings, conflict detection. Pure. |
| `AppHotkeyCatalog` | Merges installed apps, running apps, and saved shortcuts into the Settings list. Pure. |
| `HIDKeyMapping` / `HIDKeyRemapper` | The `hidutil` `UserKeyMapping` format (pure parser and JSON argument) and the process that runs `/usr/bin/hidutil` to map the chosen key to F18 and back. Photon only ever removes its own entries, and `HIDKeyRemapper` refuses a key another tool already remaps (`sourceAlreadyMapped`). |
| `HyperKeyEngine` | Session `CGEventTap` on the main run loop. Swallows F18 (and Caps Lock when it is the Hyper source), adds the four modifier flags to keys typed while it is held, dispatches keys that have a Hyper shortcut, and runs the tap behaviour (nothing / Escape / Caps Lock via `IOHIDSetModifierLockState`) on a quick press. Caps Lock as Hyper holds the lock at its latched state (off unless On tap is Toggle Caps Lock) on key down/up and `flagsChanged`. Re-enables itself and drops held Hyper state when macOS disables the tap. |
| `WindowManager` | Accessibility API: frontmost app's focused window, `kAXPosition`/`kAXSize` (set size, position, size again; `AXEnhancedUserInterface` off while moving), multi-display via `NSScreen.visibleFrame`, per-window restore history. |
| `AppActivator` | App hotkey behaviour: hide when frontmost, otherwise launch or focus through `NSWorkspace`. |
| `AccessibilityPermission` | `AXIsProcessTrusted(WithOptions)`, `CGPreflightListenEventAccess`, System Settings deep links. |
| `CapsLockState` | Reads and sets the Caps Lock lock via IOHIDSystem while Caps Lock is Hyper. |
| `KeybindsProvider` | Puts the window commands in the launcher (`window:<action>` ids). |

Shortcut routing: plain combinations go through the app's `HotkeyManager` (Carbon) via the `GlobalHotkeyRegistrar` protocol the app implements; Hyper combinations fire from the event tap while the Hyper key is held and are also registered with Carbon so pressing the four modifiers by hand works. While a recorder is active the controller pauses dispatch so bound shortcuts can be re-recorded.

Safety: the HID remap is only installed after the event tap exists, is removed on quit, disable, permission loss, or failure, is cleaned up on the next launch after a crash, and is never persistent (macOS drops it at logout). Nothing in the module prompts for Accessibility except a one-time first-run alert and explicit user actions on the Keybinds tab.

## CI

`.github/workflows/ci.yml` runs on pull requests and pushes to `develop` / `main`:

| Job | Runner | What |
| --- | --- | --- |
| `branch-name` | ubuntu-latest | Enforces `feature/GH-<n>-*`, `bug/GH-<n>-*`, `chore/*`, `docs/*`, `release/*` (passes for `develop`/`main` themselves). |
| `lint` | macos-latest | `swiftformat --lint` and `swiftlint lint --strict`. |
| `test` | macos-latest | `swift test` (PhotonCoreTests, PhotonAppsTests, PhotonClipboardTests, PhotonNotesTests, PhotonFilesTests, PhotonKeybindsTests). |
| `build` | macos-latest | `Scripts/package_app.sh`, uploads `Photon.app` (as a `ditto` zip so permissions and the signature survive). |
| `smoke` | macos-latest | Downloads that zip, records `sw_vers` / SDK, runs the crash/liveness smoke check, then launches the packaged app through `Scripts/check-native-parity.sh`. The native harness posts real global hotkeys (including ⌘,), mouse, typing, arrows, and appearance changes; it asserts process activation policy, status-menu presence, `NSPanel` style/frame, Settings visibility, launched-app frontmost, `CGWindow` bounds, expanded clipboard lifecycle, and application icon resolution. |

`branch-name`, `lint`, `build`, `test`, and `smoke` are the required status checks. SwiftPM `.build` is cached per job.

`.github/workflows/release.yml` runs on `v*.*.*` tags and, as a dry run, on `workflow_dispatch`. See [releasing.md](releasing.md).

## Local build

```sh
Scripts/package_app.sh
open build/Photon.app
```

See [CONTRIBUTING.md](../CONTRIBUTING.md).

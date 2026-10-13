# Photon

<p align="center">
  <img src="docs/assets/icon.png" width="128" height="128" alt="Photon icon">
</p>

Photon is a stripped-down, macOS-only launcher. It opens instantly, stays out of the Dock, and covers the few things that actually get used: applications, clipboard history, notes, file search, and keybinds.

It is not an extension platform. There is no AI, no account, no cloud sync, and no telemetry.

Photon is written in **Swift 6**, with AppKit for native macOS window/process behavior and SwiftUI for interface content. Version 0.3.1 restored this stack after the v0.3.0 Rust/GPUI rewrite failed the native parity gate.

## Features

- **Launcher** — `Cmd+Space` opens a compact floating search field on the screen under the mouse that expands into results as you type. A Dock-style dot sits under the icon of an application that is running. Down on the empty bar shows Suggestions; turn them on under **Settings > Appearance** to see them before typing. `⌘K` opens the actions for the selected row, and the footer shows the Return action. Esc clears the search text first, then leaves clipboard or Files, then closes the launcher. `⌘W` closes it too. Reopening within 90 seconds of a hotkey toggle or a click elsewhere returns to the same view and query. A query with no matches offers Search Files with that text. Configurable hotkey, panel width, and light/dark appearance. `⌘,` opens Settings.
- **Applications** — fuzzy search over `/Applications`, `/System/Applications`, `~/Applications`, `/System/Library/CoreServices/Applications`, and System Settings panes, ranked by match quality, with frecency breaking ties. Typing an app's exact name lists it first. An empty launcher leads with Suggestions: the applications and commands you open most, from local use counts. Anything you have not opened stays further down the list. A small dot marks running regular (Dock) apps. App rows offer Show in Finder `⌘↵`, Copy Path, Copy Name, Copy Bundle Identifier, and Quit Application in the `⌘K` panel. Photon hides first, then brings the launched app above everything.
- **Calculator** — type math or a conversion in the launcher: `20% of 50`, `2^10`, `10 km to mi`, `32 f to c`, `1 in to cm`. `×` `÷` `−` and your locale's grouping and decimal separators work. Return copies the answer.
- **Clipboard history** — `Cmd+Shift+V`, or type `cb ` in the launcher. It opens expanded on the newest entry, with the list and that entry's detail. Text (with rich text), links, images, and files; searchable, pin, paste back or copy. Return runs the **Primary Action** setting (Paste to Active App or Copy to Clipboard) and `⌘↵` runs the other one. `⇧⌘P` pins, `⌃X` deletes an entry, `⌃⇧X` deletes all after a confirmation, and `⌘K` lists these actions. Retention of 1, 7 or 30 days, 3 or 6 months, 1 year, or forever, an item limit, and excluded apps (password managers by default).
- **Notes** — a floating window with live markdown styling, one `.md` file per note in `~/Library/Application Support/Photon/Notes` (`Photon-Dev/Notes` for the dev build), and autosave. `⌘P` opens the note switcher (Pinned and Notes sections, `⇧⌘P` pins, `⌃X` deletes, `⌘1`–`⌘9` open pinned notes). `⌘K` lists note actions. Raycast format shortcuts: `⌘B` `⌘I` `⌘U` `⇧⌘S`, `⌘E` inline code, `⌥⌘C` code block, `⌘L` link, `⇧⌘B` quote, `⇧⌘7` `⇧⌘8` `⇧⌘9` lists, `⌥⌘1`–`⌥⌘3` headings. Emphasis, heading, list, and quote formats come off when applied again. `⌘↵` toggles the task on the current line. Type `notes` or `n <title>` in the launcher to open a note, or run *Create Note* or *Search Notes*; an optional hotkey toggles the window.
- **File search** — type `/` or `f ` (or run *Search Files*) to search your home folder through Spotlight (`mdfind`). Enter runs the **Settings > Files** Enter action (Open by default), `Cmd+Enter` runs the other one (Show in Finder), `Cmd+Y` toggles Quick Look, `Option+Cmd+C` copies the path, and `Cmd+K` lists the actions. Spotlight system files under `~/Library` are skipped. For queries of three or more characters, up to five file matches also appear after the other results in the main list. The launcher stays in that list as they arrive.
- **Keybinds** — a Hyper key (Caps Lock held = `⌃⌥⇧⌘`, shown as `✦`; tap = nothing, Escape, or Caps Lock — Caps Lock as Hyper only turns Caps Lock on when On tap is Toggle Caps Lock), shortcuts for installed and running apps from a list in Settings, and window management: halves, quarters, thirds, two-thirds, maximize, almost maximize, center, next/previous display, restore. Pressing a half shortcut again cycles ½ → ⅔ → ⅓. Defaults: `✦←` `✦→` `✦↑` `✦↓` halves, `✦Return` maximize, `✦C` center, `✦[` / `✦]` displays. Every command is also searchable in the launcher.

## Install

For a fresh install:

```sh
brew tap ryan-stoffel/taps
brew trust ryan-stoffel/taps          # Homebrew 7+
brew install --cask ryan-stoffel/taps/photon
```

If Photon is already installed and Homebrew still references the retired tap:

```sh
brew untap ryanstoffel/homebrew-tap   # only if that stale tap is present
brew tap ryan-stoffel/taps
brew trust ryan-stoffel/taps          # Homebrew 7+
brew update
brew upgrade --cask ryan-stoffel/taps/photon
```

Ryan's GitHub account was renamed from `RyanStoffel` to `ryan-stoffel`. GitHub redirects old repository links, but Homebrew records tap trust by name, so use the canonical `ryan-stoffel/taps` name in every Homebrew command.

Or download `Photon-<version>.zip` or `.dmg` from the [latest release](https://github.com/ryan-stoffel/photon/releases) and move `Photon.app` to `/Applications`. Requires macOS 14 or later; the binary is universal (Apple silicon and Intel).

Photon is distributed from [ryan-stoffel/homebrew-taps](https://github.com/ryan-stoffel/homebrew-taps). Current builds are ad-hoc signed and not notarized, so macOS Gatekeeper blocks the first launch of a downloaded copy:

- macOS 14: Control-click `Photon.app` and choose **Open**.
- macOS 15 and later: open Photon once, then go to **System Settings > Privacy & Security** and click **Open Anyway**.
- Or remove the quarantine flag: `xattr -dr com.apple.quarantine /Applications/Photon.app`

Releases are listed in [CHANGELOG.md](CHANGELOG.md). CI launches the packaged app on a GitHub-hosted Mac and exercises native panel, Dock/menu, appearance, frame, icon, clipboard, and global-hotkey behavior.

## Permissions

Photon is a menu-bar agent (`LSUIElement`). It does not appear in the Dock.

| Permission | When | Why |
| --- | --- | --- |
| none for the launcher itself | Phase 1 | `RegisterEventHotKey` does not require Input Monitoring. |
| Keyboard shortcuts | in the introduction | macOS Spotlight also defaults to `Cmd+Space`. The welcome window says when Spotlight uses the launcher shortcut and offers **Open Keyboard Settings**, so you can disable Spotlight's shortcut under **System Settings > Keyboard > Keyboard Shortcuts > Spotlight**. |
| Login Item | optional | "Launch at login" on the General settings tab uses `SMAppService`, and the toggle shows its real status. |
| Accessibility | Keybinds tab, or a one-time alert if the Hyper key is on | Pasting a clipboard item into the frontmost app (Photon sends `Cmd+V`; without it, Return copies the item and shows a hint). Required for the Hyper key (a keyboard event tap) and window management (moving windows through the Accessibility API). The introduction does not ask. Status stays under **Settings > Keybinds**. Without it Caps Lock keeps its normal behaviour. |
| Input Monitoring | Keybinds tab | Not asked during the introduction. The launcher shortcut itself is still a Carbon hotkey. |
| Full Disk Access | optional | File search only sees what Spotlight indexes; folders in Spotlight Privacy stay hidden. Photon adds its own excluded-folders list under **Settings > Files**. |

### How the Hyper key works

While the Hyper key is enabled and Accessibility is granted, Photon remaps the chosen key (Caps Lock by default) to F18 for the current login session using the same `hidutil` user key mapping Hyperkey-style apps use, then translates F18 into `⌃⌥⇧⌘` with an event tap. When Caps Lock is Hyper, Photon holds the Caps Lock state off, or at the state the last tap set when On tap is Toggle Caps Lock. Photon refuses a key that another tool already remaps with `hidutil`. The mapping is removed when the Hyper key is turned off or Photon quits, and macOS clears it at logout anyway. **Settings > Keybinds > Reset Key Mapping** puts the key back by hand if anything goes wrong. It is also offered while the status is Active.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for the branching model, commit style, and PR flow.

```sh
git clone https://github.com/ryan-stoffel/photon.git
cd photon
Scripts/package_app.sh
Scripts/package_app.sh --dev   # build/Photon-Dev.app, separate bundle id
Scripts/check-harness.sh
# macOS only; exercises the packaged Photon.app
Scripts/check-native-parity.sh build/Photon.app
```

Architecture: [docs/architecture.md](docs/architecture.md). Harness: [docs/harness.md](docs/harness.md). Releases: [docs/releasing.md](docs/releasing.md).

## License

[MIT](LICENSE)

[Sora](https://fonts.google.com/specimen/Sora) by the Sora Project Authors is included under `Resources/Fonts` ([SIL Open Font License](Resources/Fonts/OFL.txt)). The interface uses the system font.

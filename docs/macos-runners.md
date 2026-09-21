# GitHub Actions macOS runners

Photon CI uses `macos-latest`. Workers cannot compile AppKit locally, so this file is the record of what that image actually is.

The `lint` and `smoke` jobs print `sw_vers`, `xcodebuild -version`, and `xcrun --sdk macosx --show-sdk-version`. Smoke also uploads a `gha-macos-runner` artifact. The packaged native-parity harness prints the same OS string from `ProcessInfo` and whether `NSGlassEffectView` exists at runtime.

## As of Photon 0.4.0

Fill in from the first green `smoke` log on `feature/GH-178-launch-settings-perf` / `v0.4.0`:

| Field | Value |
| --- | --- |
| `ProductName` / `ProductVersion` | See the `Record runner OS and SDK` step |
| `xcodebuild` | See the same step |
| macOS SDK | See `SDK:` in that step |
| `NSGlassEffectView` | Printed by `Scripts/native-macos-parity.swift` as `Liquid Glass NSGlassEffectView: true/false` |

Deployment target stays **macOS 14**. Liquid Glass is a runtime fallback, not a raised minimum.

If `macos-latest` is still 15 or 26, availability + the latest SDK on that image is enough; do not break CI by requiring macOS 27 types at compile time.

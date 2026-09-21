# GitHub Actions macOS runners

Photon CI uses `macos-latest`. Workers cannot compile AppKit locally, so this file is the record of what that image actually is.

The `lint` and `smoke` jobs print `sw_vers`, `xcodebuild -version`, and `xcrun --sdk macosx --show-sdk-version`. Smoke also uploads a `gha-macos-runner` artifact. The packaged native-parity harness prints the same OS string from `ProcessInfo` and whether `NSGlassEffectView` exists at runtime.

## As of Photon 0.4.0

Recorded on `macos-latest` (`macos-26-arm64`, image `20260907.0351`) during PR [#183](https://github.com/ryan-stoffel/photon/pull/183):

| Field | Value |
| --- | --- |
| ProductName | macOS |
| ProductVersion | 26.6.2 (Build 25G83) |
| Xcode | 26.6 (17F113) |
| macOS SDK | 26.5 |
| `NSGlassEffectView` | true |

Deployment target stays **macOS 14**. Liquid Glass is selected at runtime when `NSGlassEffectView` exists. The 26.5 SDK knows that type; Photon still does not reference it at compile time so older toolchains keep building.

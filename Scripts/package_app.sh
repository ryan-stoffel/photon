#!/usr/bin/env bash
# Build a Photon app bundle from the Swift package and ad-hoc sign it.
#
#   Scripts/package_app.sh           -> build/Photon.app
#   Scripts/package_app.sh --dev     -> build/Photon-Dev.app
#   PHOTON_DEV=1 Scripts/package_app.sh
#
# The dev bundle uses com.ryanstoffel.photon.dev, the product name Photon-Dev,
# and a yellow "dev" tag on the app icon. The default (no switch) stays the
# release app: Photon.app, com.ryanstoffel.photon, unmodified icon.
#
# Set PHOTON_ARCHS="arm64 x86_64" to build a universal binary (the release
# workflow does). By default SwiftPM builds for the host architecture only.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DEV=0
if [[ "${PHOTON_DEV:-}" == "1" ]]; then
  DEV=1
fi

usage() {
  cat <<'EOF'
Usage: Scripts/package_app.sh [--dev]

  --dev    Build build/Photon-Dev.app (bundle id com.ryanstoffel.photon.dev).
           PHOTON_DEV=1 is the same switch.

The default build is build/Photon.app.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dev) DEV=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage >&2
      exit 2
      ;;
  esac
done

VERSION="$(tr -d '[:space:]' < VERSION)"
if [[ "$DEV" == "1" ]]; then
  if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "PHOTON_DEV requires macOS (the dev icon is badged with AppKit)." >&2
    exit 2
  fi
  PRODUCT_NAME="Photon-Dev"
  BUNDLE_ID="com.ryanstoffel.photon.dev"
else
  PRODUCT_NAME="Photon"
  BUNDLE_ID="com.ryanstoffel.photon"
fi

APP="$ROOT/build/${PRODUCT_NAME}.app"
CONTENTS="$APP/Contents"

BUILD_ARGS=(-c release --package-path "$ROOT")
for arch in ${PHOTON_ARCHS:-}; do
  BUILD_ARGS+=(--arch "$arch")
done

swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$BIN_DIR/Photon" "$CONTENTS/MacOS/$PRODUCT_NAME"
if [[ "$DEV" == "1" ]]; then
  swift "$ROOT/Scripts/badge-dev-icon.swift" \
    "$ROOT/Resources/Photon.icns" \
    "$CONTENTS/Resources/Photon.icns"
else
  cp "$ROOT/Resources/Photon.icns" "$CONTENTS/Resources/Photon.icns"
fi
mkdir -p "$CONTENTS/Resources/Fonts"
cp "$ROOT/Resources/Fonts/"*.ttf "$CONTENTS/Resources/Fonts/"
cp "$ROOT/Resources/Fonts/OFL.txt" "$CONTENTS/Resources/Fonts/OFL.txt"
sed \
  -e "s/VERSION_PLACEHOLDER/${VERSION}/g" \
  -e "s/PRODUCT_NAME_PLACEHOLDER/${PRODUCT_NAME}/g" \
  -e "s/BUNDLE_ID_PLACEHOLDER/${BUNDLE_ID}/g" \
  "$ROOT/Resources/Info.plist" > "$CONTENTS/Info.plist"
chmod +x "$CONTENTS/MacOS/$PRODUCT_NAME"

if [[ "$(uname -s)" == "Darwin" ]]; then
  plutil -lint "$CONTENTS/Info.plist" >/dev/null
  actual_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$CONTENTS/Info.plist")"
  actual_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleName' "$CONTENTS/Info.plist")"
  actual_display="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$CONTENTS/Info.plist")"
  actual_exec="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$CONTENTS/Info.plist")"
  if [[ "$actual_id" != "$BUNDLE_ID" || "$actual_name" != "$PRODUCT_NAME" || "$actual_display" != "$PRODUCT_NAME" || "$actual_exec" != "$PRODUCT_NAME" ]]; then
    echo "Info.plist identity does not match ${PRODUCT_NAME} (${BUNDLE_ID})." >&2
    exit 1
  fi
  codesign --force --deep --sign - "$APP"
fi

printf '%s\n' "$APP"

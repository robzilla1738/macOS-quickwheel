#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_DIR="$ROOT_DIR/build/Quickwheel.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"

swift build -c "$CONFIGURATION" --package-path "$ROOT_DIR"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"

cp "$ROOT_DIR/.build/$CONFIGURATION/Quickwheel" "$MACOS_DIR/Quickwheel"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
find "$ROOT_DIR/Resources" -maxdepth 1 -type f ! -name "Info.plist" -exec cp {} "$RESOURCES_DIR/" \;

SPARKLE_FRAMEWORK="$(find "$ROOT_DIR/.build" -path "*/Sparkle.framework" -type d | head -1)"
if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
  echo "error: Sparkle.framework was not found after swift build" >&2
  exit 1
fi

cp -R "$SPARKLE_FRAMEWORK" "$FRAMEWORKS_DIR/"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$MACOS_DIR/Quickwheel" 2>/dev/null || true

chmod +x "$MACOS_DIR/Quickwheel"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null
fi

echo "$APP_DIR"

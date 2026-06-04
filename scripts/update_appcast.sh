#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZIP_PATH="${1:-}"
TAG_NAME="${2:-}"
REPO_SLUG="${REPO_SLUG:-robzilla1738/macOS-quickwheel}"

if [[ -z "$ZIP_PATH" || -z "$TAG_NAME" ]]; then
  echo "usage: scripts/update_appcast.sh <path-to-zip> <git-tag>" >&2
  exit 1
fi

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "error: release archive not found: $ZIP_PATH" >&2
  exit 1
fi

GENERATE_APPCAST="${GENERATE_APPCAST:-$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast}"
if [[ ! -x "$GENERATE_APPCAST" ]]; then
  echo "error: Sparkle generate_appcast tool not found at $GENERATE_APPCAST" >&2
  echo "run: swift package resolve" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "$WORK_DIR"' EXIT

if [[ -f "$ROOT_DIR/appcast.xml" ]]; then
  cp "$ROOT_DIR/appcast.xml" "$WORK_DIR/appcast.xml"
fi

cp "$ZIP_PATH" "$WORK_DIR/"

DOWNLOAD_URL_PREFIX="${APPCAST_DOWNLOAD_URL_PREFIX:-https://github.com/$REPO_SLUG/releases/download/$TAG_NAME/}"

"$GENERATE_APPCAST" \
  --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
  --link "https://github.com/$REPO_SLUG/releases" \
  -o "$WORK_DIR/appcast.xml" \
  "$WORK_DIR"

cp "$WORK_DIR/appcast.xml" "$ROOT_DIR/appcast.xml"
echo "$ROOT_DIR/appcast.xml"

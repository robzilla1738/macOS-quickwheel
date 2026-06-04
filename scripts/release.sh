#!/usr/bin/env bash
set -euo pipefail

# Builds, signs (Developer ID + hardened runtime), notarizes, and staples
# build/Quickwheel.app, producing a distributable zip in build/.
#
# Requirements:
#   - A "Developer ID Application" identity in the keychain.
#   - notarytool credentials stored under a keychain profile
#     (xcrun notarytool store-credentials).
#
# Overrides:
#   SIGNING_IDENTITY  codesign identity (default: first Developer ID Application)
#   NOTARY_PROFILE    notarytool keychain profile name (default: notarytool)

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/build/Quickwheel.app"
ENTITLEMENTS="$ROOT_DIR/scripts/Quickwheel.entitlements"
NOTARY_PROFILE="${NOTARY_PROFILE:-notarytool}"

if [[ -z "${SIGNING_IDENTITY:-}" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)"/\1/')"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
  echo "error: no Developer ID Application identity found" >&2
  exit 1
fi

echo "==> Building release app"
"$ROOT_DIR/scripts/build_app.sh" release

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP_DIR/Contents/Info.plist")"
ZIP_PATH="$ROOT_DIR/build/Quickwheel-$VERSION.zip"

echo "==> Signing with: $SIGNING_IDENTITY"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGNING_IDENTITY" \
  "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

echo "==> Submitting for notarization (profile: $NOTARY_PROFILE)"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket"
xcrun stapler staple "$APP_DIR"
spctl --assess --type execute --verbose=2 "$APP_DIR"

echo "==> Repacking stapled app"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "Release artifact: $ZIP_PATH"

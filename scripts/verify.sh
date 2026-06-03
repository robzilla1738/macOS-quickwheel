#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

swift test --package-path "$ROOT_DIR"

if command -v xcodegen >/dev/null 2>&1; then
  xcodegen generate --spec "$ROOT_DIR/project.yml"
else
  echo "warning: xcodegen not found; using the checked-in Quickwheel.xcodeproj" >&2
fi

xcodebuild \
  -project "$ROOT_DIR/Quickwheel.xcodeproj" \
  -scheme Quickwheel \
  -configuration Debug \
  build

"$ROOT_DIR/scripts/build_app.sh"

codesign --verify --deep --strict "$ROOT_DIR/build/Quickwheel.app"

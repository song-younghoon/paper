#!/bin/bash
# Build Paper.app from the SwiftPM executable and assemble a signed .app bundle.
# Usage:
#   ./build.sh            # release build + bundle
#   ./build.sh debug      # debug build + bundle
#   ./build.sh release run  # build then launch
set -euo pipefail
cd "$(dirname "$0")"

CONFIG="${1:-release}"
RUN="${2:-}"

echo "▸ swift build ($CONFIG) …"
swift build -c "$CONFIG"

BIN=".build/$CONFIG/Paper"
APP="build/Paper.app"

echo "▸ assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Paper"
cp Packaging/Info.plist "$APP/Contents/Info.plist"
if [ -f "Packaging/AppIcon.icns" ]; then
  cp "Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "▸ code signing (ad-hoc) …"
codesign --force --sign - "$APP" >/dev/null 2>&1 || echo "  (codesign skipped)"

echo "▸ done: $APP"

if [ "$RUN" = "run" ]; then
  echo "▸ launching …"
  open "$APP"
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
APP="$ROOT/dist/Awqat.app"
APP_BINARY="$BUILD_DIR/Awqat"
SDK="$(xcrun --sdk macosx --show-sdk-path)"

mkdir -p "$BUILD_DIR/module-cache"
mkdir -p "$ROOT/dist"

echo "Compiling Awqat..."
# Paths in this repository contain no spaces, so word splitting here is intentional.
SOURCES=$(find "$ROOT/Vendor/Adhan/Sources" "$ROOT/Sources/Core" "$ROOT/Sources/App" -name '*.swift' -print | sort)
# shellcheck disable=SC2086
xcrun --sdk macosx swiftc \
    -swift-version 5 \
    -O \
    -whole-module-optimization \
    -target arm64-apple-macosx14.0 \
    -sdk "$SDK" \
    -module-cache-path "$BUILD_DIR/module-cache" \
    -framework AppKit \
    $SOURCES \
    -o "$APP_BINARY"

echo "Building app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$APP_BINARY" "$APP/Contents/MacOS/Awqat"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

if [ -f "$ROOT/Resources/Awqat.icns" ]; then
    cp "$ROOT/Resources/Awqat.icns" "$APP/Contents/Resources/Awqat.icns"
fi

if [ -f "$ROOT/THIRD_PARTY_NOTICES.md" ]; then
    cp "$ROOT/THIRD_PARTY_NOTICES.md" "$APP/Contents/Resources/THIRD_PARTY_NOTICES.md"
fi

plutil -lint "$APP/Contents/Info.plist" >/dev/null
codesign --force --sign - "$APP" >/dev/null

echo "Built: $APP"
echo "Size:  $(du -sh "$APP" | awk '{print $1}')"
codesign --verify --strict "$APP"
echo "Signature verified."

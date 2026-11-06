#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT/.build"
mkdir -p "$BUILD_DIR/module-cache"

echo "Compiling core checks..."
SOURCES=$(find "$ROOT/Vendor/Adhan/Sources" "$ROOT/Sources/Core" -name '*.swift' -print | sort)
# shellcheck disable=SC2086
xcrun --sdk macosx swiftc \
    -swift-version 5 \
    -Onone \
    -target arm64-apple-macosx14.0 \
    -module-cache-path "$BUILD_DIR/module-cache" \
    $SOURCES \
    "$ROOT/Tests/main.swift" \
    -o "$BUILD_DIR/AwqatChecks"

"$BUILD_DIR/AwqatChecks"

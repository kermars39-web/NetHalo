#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_DIR="$PROJECT_DIR/dist/NetHalo.app"
CONTENTS_DIR="$APP_DIR/Contents"

# Keep compiler caches writable when the app is built from a restricted agent.
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$PROJECT_DIR/.build/ModuleCache.noindex}"
export SWIFT_MODULECACHE_PATH="${SWIFT_MODULECACHE_PATH:-$CLANG_MODULE_CACHE_PATH}"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$SWIFT_MODULECACHE_PATH"
BUILD_ARGS=(
  --disable-sandbox --package-path "$PROJECT_DIR"
  --scratch-path "${NETHALO_BUILD_PATH:-$PROJECT_DIR/.build}"
  -c release -debug-info-format none
  -Xswiftc -module-cache-path -Xswiftc "$SWIFT_MODULECACHE_PATH"
)
swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
"$BIN_DIR/NetHalo" --self-test

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/NetHalo" "$CONTENTS_DIR/MacOS/NetHalo"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/NetHalo.icns" "$CONTENTS_DIR/Resources/NetHalo.icns"
cp "$PROJECT_DIR/Resources/AppIcon.png" "$CONTENTS_DIR/Resources/AppIcon.png"
chmod 755 "$CONTENTS_DIR/MacOS/NetHalo"

codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"

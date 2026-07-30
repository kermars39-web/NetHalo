#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
APP_DIR="$PROJECT_DIR/dist/NetHalo.app"
CONTENTS_DIR="$APP_DIR/Contents"

swift build --disable-sandbox --package-path "$PROJECT_DIR" -c release
BIN_DIR="$(swift build --disable-sandbox --package-path "$PROJECT_DIR" -c release --show-bin-path)"
"$BIN_DIR/NetHalo" --self-test

rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
cp "$BIN_DIR/NetHalo" "$CONTENTS_DIR/MacOS/NetHalo"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod 755 "$CONTENTS_DIR/MacOS/NetHalo"

codesign --force --deep --sign - "$APP_DIR"

echo "$APP_DIR"

#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/NetHalo.app"
DMG_PATH="$PROJECT_DIR/dist/NetHalo-1.0-macOS-arm64.dmg"
STAGING_DIR="$(mktemp -d /private/tmp/nethalo-dmg.XXXXXX)"

cleanup() {
  rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

if [[ ! -d "$APP_PATH" ]]; then
  echo "Missing $APP_PATH. Run ./Scripts/build-app.sh first." >&2
  exit 1
fi

ditto "$APP_PATH" "$STAGING_DIR/NetHalo.app"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "NetHalo 1.0" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$DMG_PATH"

hdiutil verify "$DMG_PATH"
shasum -a 256 "$DMG_PATH"

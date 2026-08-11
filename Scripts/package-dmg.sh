#!/bin/zsh

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/dist/NetHalo.app"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
VERSIONED_DMG_PATH="$PROJECT_DIR/dist/NetHalo-${VERSION}-macOS-arm64.dmg"
STABLE_DMG_PATH="$PROJECT_DIR/dist/NetHalo-macOS-arm64.dmg"
CHECKSUM_PATH="$PROJECT_DIR/dist/SHA256SUMS.txt"
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
  -volname "NetHalo $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -format UDZO \
  -ov \
  "$VERSIONED_DMG_PATH"

hdiutil verify "$VERSIONED_DMG_PATH"
cp -f "$VERSIONED_DMG_PATH" "$STABLE_DMG_PATH"

(
  cd "$PROJECT_DIR/dist"
  shasum -a 256 \
    "$(basename "$VERSIONED_DMG_PATH")" \
    "$(basename "$STABLE_DMG_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

cat "$CHECKSUM_PATH"

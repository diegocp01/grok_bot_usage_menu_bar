#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:?Set VERSION, for example VERSION=0.1.0}"
APP_NAME="Grok Usage Menu Bar"
RELEASE_OUT_DIR="${RELEASE_OUT_DIR:-/private/tmp/grok-usage-menu-bar-notarized}"
APP_PATH="$RELEASE_OUT_DIR/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/.build/dist"
ZIP_PATH="$DIST_DIR/GrokUsageMenuBar-$VERSION-macOS-universal.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

: "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity}"
: "${APPLE_ID:?Set APPLE_ID for notarization}"
: "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID for notarization}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?Set APPLE_APP_SPECIFIC_PASSWORD for notarization}"

command -v gh >/dev/null 2>&1 || { echo "Install GitHub CLI first." >&2; exit 1; }
git -C "$ROOT_DIR" remote get-url origin >/dev/null

mkdir -p "$DIST_DIR"
rm -rf "$RELEASE_OUT_DIR"
OUT_DIR="$RELEASE_OUT_DIR" CODESIGN_IDENTITY="$DEVELOPER_ID_APPLICATION" VERSION="$VERSION" "$ROOT_DIR/scripts/build.sh" >/dev/null

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD" \
  --wait

xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

(
  cd "$ROOT_DIR"
  gh release create "v$VERSION" "$ZIP_PATH" "$CHECKSUM_PATH" \
    --title "v$VERSION" \
    --notes "Signed and notarized universal macOS app bundle."
)

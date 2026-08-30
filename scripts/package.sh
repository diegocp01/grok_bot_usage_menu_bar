#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-0.1.0}"
APP_NAME="Grok Usage Menu Bar"
RELEASE_OUT_DIR="${RELEASE_OUT_DIR:-/private/tmp/grok-usage-menu-bar-package}"
APP_PATH="$RELEASE_OUT_DIR/$APP_NAME.app"
DIST_DIR="$ROOT_DIR/.build/dist"
ZIP_PATH="$DIST_DIR/GrokUsageMenuBar-$VERSION-macOS-universal.zip"
CHECKSUM_PATH="$ZIP_PATH.sha256"

mkdir -p "$DIST_DIR"
rm -rf "$RELEASE_OUT_DIR"
OUT_DIR="$RELEASE_OUT_DIR" VERSION="$VERSION" "$ROOT_DIR/scripts/build.sh" >/dev/null

rm -f "$ZIP_PATH" "$CHECKSUM_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"
(
  cd "$DIST_DIR"
  shasum -a 256 "$(basename "$ZIP_PATH")" > "$(basename "$CHECKSUM_PATH")"
)

echo "$ZIP_PATH"
echo "$CHECKSUM_PATH"

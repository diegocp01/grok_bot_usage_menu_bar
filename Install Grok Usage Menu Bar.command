#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMP_BUILD="$(mktemp -d "${TMPDIR:-/private/tmp}/grok-usage-menu-bar.XXXXXX")"
trap 'rm -rf "$TEMP_BUILD"' EXIT

OUT_DIR="$TEMP_BUILD" "$ROOT_DIR/scripts/build.sh" >/dev/null
SOURCE_APP="$TEMP_BUILD/Grok Usage Menu Bar.app"
DESTINATION="$HOME/Applications/Grok Usage Menu Bar.app"

mkdir -p "$HOME/Applications"
pkill -x GrokUsageMenuBar >/dev/null 2>&1 || true
rm -rf "$DESTINATION"
ditto --noqtn "$SOURCE_APP" "$DESTINATION"
xattr -cr "$DESTINATION" 2>/dev/null || true
codesign --force --sign - --options runtime "$DESTINATION" >/dev/null
codesign --verify --deep --strict "$DESTINATION"
open "$DESTINATION"

echo "Installed and opened:"
echo "$DESTINATION"

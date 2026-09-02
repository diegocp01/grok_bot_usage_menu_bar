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
sleep 1

LOGIN_STATUS="$("$DESTINATION/Contents/MacOS/GrokUsageMenuBar" --launch-at-login-status 2>/dev/null || true)"

echo "Installed and opened:"
echo "$DESTINATION"
if [[ "$LOGIN_STATUS" == "enabled" ]]; then
  echo "Launch at Login: enabled"
else
  echo "Launch at Login: $LOGIN_STATUS"
  echo "If approval is required, enable Grok Usage Menu Bar in System Settings > General > Login Items."
fi

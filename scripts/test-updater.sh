#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT_DIR/.build/updater-tests"
clang -fobjc-arc -mmacosx-version-min=13.0 -framework Foundation \
  -I "$ROOT_DIR/Sources/GrokUsageMenuBar" "$ROOT_DIR/Tests/UpdaterTests.m" \
  -o "$ROOT_DIR/.build/updater-tests/UpdaterTests"
"$ROOT_DIR/.build/updater-tests/UpdaterTests"

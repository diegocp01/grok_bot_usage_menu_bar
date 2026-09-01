#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ROOT_DIR/.build/tests"
mkdir -p "$TEST_DIR" "$ROOT_DIR/.build/module-cache"

env CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache" \
  clang \
  "$ROOT_DIR/Tests/ParserTests.m" \
  "$ROOT_DIR/Sources/GrokUsageMenuBar/GrokUsageParser.m" \
  -I "$ROOT_DIR/Sources/GrokUsageMenuBar" \
  -fobjc-arc \
  -framework Foundation \
  -o "$TEST_DIR/ParserTests"

"$TEST_DIR/ParserTests"

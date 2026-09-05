#!/bin/zsh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
swift build --product CodexProfilesCheck
TEST_BINARY="$(swift build --show-bin-path)/CodexProfilesCheck"
# Stamp the completed test executable explicitly on both Xcode and CLT toolchains.
codesign --force --sign - "$TEST_BINARY"
codesign --verify --strict "$TEST_BINARY"
"$TEST_BINARY"

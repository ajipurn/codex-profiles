#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
CONFIGURATION="${1:-debug}"
[[ "$CONFIGURATION" == debug || "$CONFIGURATION" == release ]] || { echo "Use debug or release" >&2; exit 1; }
python3 scripts/release_metadata.py check

# CI supplies both architectures; local builds default to the host architecture.
ARCH_ARGS=()
for arch in ${=BUILD_ARCHS:-}; do
  [[ "$arch" == arm64 || "$arch" == x86_64 ]] || { echo "Unsupported architecture: $arch" >&2; exit 1; }
  ARCH_ARGS+=(--arch "$arch")
done
swift build -c "$CONFIGURATION" --product CodexProfiles "${ARCH_ARGS[@]}"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path "${ARCH_ARGS[@]}")"
APP_DIR="$ROOT/dist/Codex Profiles.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"
SPARKLE="$ROOT/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[[ -d "$SPARKLE" ]] || { echo "Sparkle framework missing; run swift package resolve" >&2; exit 1; }

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$BIN_DIR/CodexProfiles" "$MACOS_DIR/CodexProfiles"
chmod +x "$MACOS_DIR/CodexProfiles"
cp CodexProfiles/Info.plist "$APP_DIR/Contents/Info.plist"
cp CodexProfiles/Resources/{AppIcon.icns,MenuBarIcon.png,MenuBarIcon@2x.png} "$RESOURCES_DIR/"
if [[ -d "$BIN_DIR/CodexProfiles_CodexProfiles.bundle" ]]; then
  ditto "$BIN_DIR/CodexProfiles_CodexProfiles.bundle" "$RESOURCES_DIR/CodexProfiles_CodexProfiles.bundle"
fi
ditto "$SPARKLE" "$FRAMEWORKS_DIR/Sparkle.framework"
cp THIRD_PARTY_NOTICES.md "$RESOURCES_DIR/"
cp LICENSE "$RESOURCES_DIR/LICENSE.txt"

IDENTITY="${CODE_SIGN_IDENTITY:--}"
SIGN_ARGS=(--force --sign "$IDENTITY")
if [[ "$IDENTITY" != - ]]; then
  SIGN_ARGS+=(--options runtime --timestamp)
fi
# Sign nested executables from the inside out; preserve framework symlinks.
SPARKLE_VERSION="$FRAMEWORKS_DIR/Sparkle.framework/Versions/B"
for component in "$SPARKLE_VERSION"/XPCServices/*.xpc(N) "$SPARKLE_VERSION/Autoupdate" "$SPARKLE_VERSION/Updater.app"; do
  [[ -e "$component" ]] && codesign "${SIGN_ARGS[@]}" "$component"
done
codesign "${SIGN_ARGS[@]}" "$FRAMEWORKS_DIR/Sparkle.framework"
codesign "${SIGN_ARGS[@]}" --entitlements CodexProfiles/CodexProfiles.entitlements "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"
if [[ -n "${BUILD_ARCHS:-}" ]]; then
  for arch in ${=BUILD_ARCHS}; do
    lipo "$MACOS_DIR/CodexProfiles" -verify_arch "$arch"
  done
fi
echo "Built $APP_DIR"

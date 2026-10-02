#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_CONFIGURATION="${1:-release}"
BUILD_ARCHITECTURE_ARGS=()
SWIFT_SANDBOX_ARGS=()
if [[ "${CODEX_METER_DISABLE_SWIFTPM_SANDBOX:-0}" == "1" ]]; then
    SWIFT_SANDBOX_ARGS=(--disable-sandbox)
fi
DIST_DIR="$PROJECT_DIR/dist"
APP_DIR="$DIST_DIR/CodexMeter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
HELPERS_DIR="$CONTENTS_DIR/Helpers"
LAUNCH_AGENTS_DIR="$CONTENTS_DIR/Library/LaunchAgents"
TEMP_ROOT="${TMPDIR:-/tmp}"
TEMP_ROOT="${TEMP_ROOT%/}"
if [[ "${CODEX_METER_REUSE_SWIFTPM_BUILD:-0}" == "1" ]]; then
    BUILD_SCRATCH_DIR="$PROJECT_DIR/.build"
else
    BUILD_SCRATCH_DIR="$(mktemp -d "$TEMP_ROOT/CodexMeter-build.XXXXXX")"
fi

cleanup_build_scratch() {
    if [[ "${CODEX_METER_REUSE_SWIFTPM_BUILD:-0}" == "1" ]]; then
        return
    fi
    case "$BUILD_SCRATCH_DIR" in
        "$TEMP_ROOT"/CodexMeter-build.*)
            /bin/rm -rf "$BUILD_SCRATCH_DIR"
            ;;
        *)
            print -u2 "Refusing to remove unexpected build directory: $BUILD_SCRATCH_DIR"
            ;;
    esac
}

trap cleanup_build_scratch EXIT

case "$APP_DIR" in
    "$PROJECT_DIR/dist/CodexMeter.app") ;;
    *)
        print -u2 "Refusing to build outside the project dist directory."
        exit 1
        ;;
esac

case "$BUILD_CONFIGURATION" in
    debug|release) ;;
    *)
        print -u2 "Build configuration must be debug or release."
        exit 1
        ;;
esac

if [[ "$BUILD_CONFIGURATION" == release ]]; then
    BUILD_ARCHITECTURE_ARGS=(--arch arm64 --arch x86_64)
fi

if [[ -L "$DIST_DIR" ]]; then
    print -u2 "Refusing to clean a symlinked dist directory: $DIST_DIR"
    exit 1
fi

# Both local builds and release packages start without previous artifacts.
mkdir -p "$DIST_DIR"
/bin/rm -rf -- "$DIST_DIR"/*(DN)

cd "$PROJECT_DIR"
swift build \
    --scratch-path "$BUILD_SCRATCH_DIR" \
    "${SWIFT_SANDBOX_ARGS[@]}" \
    --configuration "$BUILD_CONFIGURATION" \
    "${BUILD_ARCHITECTURE_ARGS[@]}" \
    --product CodexMeter
swift build \
    --scratch-path "$BUILD_SCRATCH_DIR" \
    "${SWIFT_SANDBOX_ARGS[@]}" \
    --configuration "$BUILD_CONFIGURATION" \
    "${BUILD_ARCHITECTURE_ARGS[@]}" \
    --product CodexMeterWatcher
BIN_DIR="$(
    swift build \
        --scratch-path "$BUILD_SCRATCH_DIR" \
        "${SWIFT_SANDBOX_ARGS[@]}" \
        --configuration "$BUILD_CONFIGURATION" \
        "${BUILD_ARCHITECTURE_ARGS[@]}" \
        --show-bin-path
)"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR" "$HELPERS_DIR" "$LAUNCH_AGENTS_DIR"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
if [[ "${CODE_SIGN_IDENTITY:--}" == "-" ]]; then
    /usr/libexec/PlistBuddy -c "Add :CodexMeterUsesLocalWatcher bool true" "$CONTENTS_DIR/Info.plist"
fi
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$PROJECT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE.txt"
cp "$BIN_DIR/CodexMeter" "$MACOS_DIR/CodexMeter"
cp "$BIN_DIR/CodexMeterWatcher" "$HELPERS_DIR/CodexMeterWatcher"
cp "$PROJECT_DIR/Resources/local.codex-meter.codex-watcher.plist" \
    "$LAUNCH_AGENTS_DIR/local.codex-meter.codex-watcher.plist"
if [[ ! -d "$BIN_DIR/Sparkle.framework" ]]; then
    print -u2 "Sparkle.framework was not found in the Swift build output."
    exit 1
fi
cp -R "$BIN_DIR/Sparkle.framework" "$FRAMEWORKS_DIR/"
if [[ -d "$BIN_DIR/CodexMeter_CodexMeter.bundle" ]]; then
    cp -R "$BIN_DIR/CodexMeter_CodexMeter.bundle" "$RESOURCES_DIR/"
fi
chmod +x "$MACOS_DIR/CodexMeter"
chmod +x "$HELPERS_DIR/CodexMeterWatcher"

if [[ "$BUILD_CONFIGURATION" == release ]]; then
    /usr/bin/strip -S "$MACOS_DIR/CodexMeter"
    /usr/bin/strip -S "$HELPERS_DIR/CodexMeterWatcher"
fi

if command -v codesign >/dev/null 2>&1; then
    CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
    SPARKLE_FRAMEWORK="$FRAMEWORKS_DIR/Sparkle.framework"
    SPARKLE_VERSION_DIR="$SPARKLE_FRAMEWORK/Versions/B"
    SPARKLE_CODE_SIGN_OPTIONS=(--options runtime)
    APP_CODE_SIGN_OPTIONS=()
    if [[ "$CODE_SIGN_IDENTITY" != "-" ]]; then
        SPARKLE_CODE_SIGN_OPTIONS+=(--timestamp)
        APP_CODE_SIGN_OPTIONS=(--options runtime --timestamp)
    fi

    codesign --force --sign "$CODE_SIGN_IDENTITY" "${SPARKLE_CODE_SIGN_OPTIONS[@]}" \
        "$SPARKLE_VERSION_DIR/XPCServices/Installer.xpc"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "${SPARKLE_CODE_SIGN_OPTIONS[@]}" \
        --preserve-metadata=entitlements \
        "$SPARKLE_VERSION_DIR/XPCServices/Downloader.xpc"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "${SPARKLE_CODE_SIGN_OPTIONS[@]}" \
        "$SPARKLE_VERSION_DIR/Autoupdate"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "${SPARKLE_CODE_SIGN_OPTIONS[@]}" \
        "$SPARKLE_VERSION_DIR/Updater.app"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "${SPARKLE_CODE_SIGN_OPTIONS[@]}" \
        "$SPARKLE_FRAMEWORK"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "${SPARKLE_CODE_SIGN_OPTIONS[@]}" \
        "$HELPERS_DIR/CodexMeterWatcher"
    codesign --force --sign "$CODE_SIGN_IDENTITY" "${APP_CODE_SIGN_OPTIONS[@]}" \
        "$APP_DIR"
fi

print "$APP_DIR"

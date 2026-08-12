#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
BUILD_CONFIGURATION="${1:-release}"
BUILD_ARCHITECTURE_ARGS=()
APP_DIR="$PROJECT_DIR/dist/CodexMeter.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
FRAMEWORKS_DIR="$CONTENTS_DIR/Frameworks"
TEMP_ROOT="${TMPDIR:-/tmp}"
TEMP_ROOT="${TEMP_ROOT%/}"
BUILD_SCRATCH_DIR="$(mktemp -d "$TEMP_ROOT/CodexMeter-build.XXXXXX")"

cleanup_build_scratch() {
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

cd "$PROJECT_DIR"
swift build \
    --scratch-path "$BUILD_SCRATCH_DIR" \
    --configuration "$BUILD_CONFIGURATION" \
    "${BUILD_ARCHITECTURE_ARGS[@]}" \
    --product CodexMeter
BIN_DIR="$(
    swift build \
        --scratch-path "$BUILD_SCRATCH_DIR" \
        --configuration "$BUILD_CONFIGURATION" \
        "${BUILD_ARCHITECTURE_ARGS[@]}" \
        --show-bin-path
)"

if [[ -d "$APP_DIR" ]]; then
    /bin/rm -rf "$APP_DIR"
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$FRAMEWORKS_DIR"
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$PROJECT_DIR/LICENSE" "$RESOURCES_DIR/LICENSE.txt"
cp "$BIN_DIR/CodexMeter" "$MACOS_DIR/CodexMeter"
if [[ ! -d "$BIN_DIR/Sparkle.framework" ]]; then
    print -u2 "Sparkle.framework was not found in the Swift build output."
    exit 1
fi
cp -R "$BIN_DIR/Sparkle.framework" "$FRAMEWORKS_DIR/"
if [[ -d "$BIN_DIR/CodexMeter_CodexMeter.bundle" ]]; then
    cp -R "$BIN_DIR/CodexMeter_CodexMeter.bundle" "$RESOURCES_DIR/"
fi
chmod +x "$MACOS_DIR/CodexMeter"

if [[ "$BUILD_CONFIGURATION" == release ]]; then
    /usr/bin/strip -S "$MACOS_DIR/CodexMeter"
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
    codesign --force --sign "$CODE_SIGN_IDENTITY" "${APP_CODE_SIGN_OPTIONS[@]}" \
        "$APP_DIR"
fi

print "$APP_DIR"

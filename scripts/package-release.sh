#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INFO_PLIST="$PROJECT_DIR/Resources/Info.plist"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
APP_DIR="$PROJECT_DIR/dist/CodexMeter.app"
ARCHIVE_NAME="CodexMeter-$VERSION-macOS.zip"
CHECKSUM_NAME="$ARCHIVE_NAME.sha256"
ARCHIVE_PATH="$PROJECT_DIR/dist/$ARCHIVE_NAME"
CHECKSUM_PATH="$PROJECT_DIR/dist/$CHECKSUM_NAME"
APPCAST_PATH="$PROJECT_DIR/dist/appcast.xml"
SPARKLE_ACCOUNT="${SPARKLE_ACCOUNT:-codex-meter}"
SPARKLE_BIN_DIR="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/bin"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
TEMP_ROOT="${TMPDIR:-/tmp}"
TEMP_ROOT="${TEMP_ROOT%/}"
APPCAST_WORK_DIR="$(mktemp -d "$TEMP_ROOT/CodexMeter-appcast.XXXXXX")"

cleanup_appcast_work_dir() {
    case "$APPCAST_WORK_DIR" in
        "$TEMP_ROOT"/CodexMeter-appcast.*)
            /bin/rm -rf "$APPCAST_WORK_DIR"
            ;;
        *)
            print -u2 "Refusing to remove unexpected appcast directory: $APPCAST_WORK_DIR"
            ;;
    esac
}

trap cleanup_appcast_work_dir EXIT

case "$VERSION" in
    <->.<->.<->) ;;
    *)
        print -u2 "CFBundleShortVersionString must use x.y.z format."
        exit 1
        ;;
esac

case "$ARCHIVE_PATH" in
    "$PROJECT_DIR/dist/CodexMeter-$VERSION-macOS.zip") ;;
    *)
        print -u2 "Refusing to package outside the project dist directory."
        exit 1
        ;;
esac

"$SCRIPT_DIR/build-app.sh" release

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
    if [[ "${CODE_SIGN_IDENTITY:--}" == "-" ]]; then
        print -u2 "NOTARYTOOL_PROFILE requires a Developer ID Application signing identity."
        exit 1
    fi
    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
    xcrun notarytool submit "$ARCHIVE_PATH" \
        --keychain-profile "$NOTARYTOOL_PROFILE" \
        --wait
    xcrun stapler staple "$APP_DIR"
    xcrun stapler validate "$APP_DIR"
fi

if [[ -f "$ARCHIVE_PATH" ]]; then
    /bin/rm "$ARCHIVE_PATH"
fi
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
(
    cd "$PROJECT_DIR/dist"
    /usr/bin/shasum -a 256 "$ARCHIVE_NAME" > "$CHECKSUM_NAME"
)

if [[ ! -x "$SPARKLE_BIN_DIR/generate_appcast" ]]; then
    swift package resolve
fi
if [[ ! -x "$SPARKLE_BIN_DIR/generate_appcast" ]]; then
    print -u2 "Sparkle release tools were not found after resolving packages."
    exit 1
fi

cp "$ARCHIVE_PATH" "$APPCAST_WORK_DIR/$ARCHIVE_NAME"
"$SPARKLE_BIN_DIR/generate_appcast" \
    --account "$SPARKLE_ACCOUNT" \
    --download-url-prefix "https://github.com/JTXYH/codex-meter/releases/download/v$VERSION/" \
    --link "https://github.com/JTXYH/codex-meter/releases/tag/v$VERSION" \
    --versions "$BUILD_VERSION" \
    --maximum-deltas 0 \
    --maximum-versions 3 \
    -o "$APPCAST_WORK_DIR/appcast.xml" \
    "$APPCAST_WORK_DIR"
cp "$APPCAST_WORK_DIR/appcast.xml" "$APPCAST_PATH"

print "$ARCHIVE_PATH"
print "$CHECKSUM_PATH"
print "$APPCAST_PATH"

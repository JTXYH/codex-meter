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
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$APP_DIR" "$ARCHIVE_PATH"
(
    cd "$PROJECT_DIR/dist"
    /usr/bin/shasum -a 256 "$ARCHIVE_NAME" > "$CHECKSUM_NAME"
)

print "$ARCHIVE_PATH"
print "$CHECKSUM_PATH"

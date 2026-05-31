#!/usr/bin/env bash
#
# build_dmg.sh — Release build + polished DMG for Clip Board Pro
#
# Usage:
#   ./build_dmg.sh              # ad-hoc sign (no Apple Developer account)
#   ./build_dmg.sh --dev-id     # sign with Developer ID from Keychain
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="$ROOT_DIR/Clip Board Pro.xcodeproj"
SCHEME="Clip Board Pro"
APP_NAME="Clip Board Pro"
DMG_NAME="Install_ClipboardManager.dmg"
BUILD_DIR="$ROOT_DIR/build"
STAGING_DIR="$BUILD_DIR/dmg-staging"
DERIVED_DATA="$BUILD_DIR/DerivedData"

SIGN_IDENTITY="-"
USE_DEV_ID=false

for arg in "$@"; do
    case "$arg" in
        --dev-id)
            USE_DEV_ID=true
            ;;
        -h|--help)
            echo "Usage: $0 [--dev-id]"
            exit 0
            ;;
    esac
done

echo "▸ Cleaning previous artifacts…"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$STAGING_DIR"

echo "▸ Checking dependencies…"
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "create-dmg is not installed."
    echo "Install with:  brew install create-dmg"
    exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "xcodebuild not found. Install Xcode."
    exit 1
fi

echo "▸ Resolving Swift packages…"
xcodebuild -resolvePackageDependencies \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -derivedDataPath "$DERIVED_DATA" \
    >/dev/null

echo "▸ Building Release (macOS)…"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    CODE_SIGN_STYLE=Manual \
    DEVELOPMENT_TEAM="" \
    clean build

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: Built app not found at $APP_PATH"
    exit 1
fi

echo "▸ Code signing app…"
if [[ "$USE_DEV_ID" == true ]]; then
    SIGN_IDENTITY=$(security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/')
    if [[ -z "$SIGN_IDENTITY" ]]; then
        echo "Error: No Developer ID Application certificate found in Keychain."
        exit 1
    fi
fi

codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_PATH"
codesign --verify --verbose=2 "$APP_PATH"

echo "▸ Staging DMG contents…"
ditto "$APP_PATH" "$STAGING_DIR/$APP_NAME.app"

echo "▸ Creating DMG with create-dmg…"
DMG_OUTPUT="$BUILD_DIR/$DMG_NAME"
rm -f "$DMG_OUTPUT"

create-dmg \
    --volname "Clip Board Pro" \
    --window-pos 200 120 \
    --window-size 660 420 \
    --icon-size 96 \
    --icon "$APP_NAME.app" 170 210 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 490 210 \
    --no-internet-enable \
    "$DMG_OUTPUT" \
    "$STAGING_DIR"

if [[ "$USE_DEV_ID" == true ]]; then
    echo "▸ Signing DMG…"
    codesign --force --sign "$SIGN_IDENTITY" "$DMG_OUTPUT"
fi

echo ""
echo "✅ Done!"
echo "   App:  $APP_PATH"
echo "   DMG:  $DMG_OUTPUT"
echo ""
echo "Next steps for Sparkle distribution:"
echo "  1. Sign update:  ./Sparkle/bin/sign_update $DMG_OUTPUT"
echo "  2. Upload DMG + update release/appcast.xml with edSignature and length"
echo "  3. Host appcast at the URL in SUFeedURL"

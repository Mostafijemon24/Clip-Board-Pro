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

ENTITLEMENTS="$ROOT_DIR/Clip Board Pro/Clip_Board_Pro.entitlements"
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

resolve_sign_identity() {
    if [[ "$USE_DEV_ID" == true ]]; then
        security find-identity -v -p codesigning | grep "Developer ID Application" | head -1 | sed 's/.*"\(.*\)".*/\1/'
        return
    fi
    local dev
    dev=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | sed 's/.*"\(.*\)".*/\1/' || true)
    if [[ -n "$dev" ]]; then
        echo "$dev"
        return
    fi
    echo "-"
}

sign_app_bundle() {
    local app="$1"
    local identity="$2"

    dot_clean -m "$app" 2>/dev/null || true
    xattr -cr "$app" 2>/dev/null || true

    local sparkle="$app/Contents/Frameworks/Sparkle.framework"
    if [[ -d "$sparkle/Versions/B" ]]; then
        dot_clean -m "$sparkle" 2>/dev/null || true
        xattr -cr "$sparkle" 2>/dev/null || true
        while IFS= read -r -d '' macho; do
            codesign --force --options runtime --sign "$identity" "$macho"
        done < <(find "$sparkle/Versions/B" -type f -print0 | while IFS= read -r -d '' f; do
            [[ "$f" == *Updater.app* ]] && continue
            if file "$f" | grep -q "Mach-O"; then printf '%s\0' "$f"; fi
        done)
        if [[ -d "$sparkle/Versions/B/Updater.app" ]]; then
            codesign --force --options runtime --sign "$identity" "$sparkle/Versions/B/Updater.app"
        fi
        codesign --force --options runtime --sign "$identity" "$sparkle"
    fi

    local executable="$app/Contents/MacOS/$APP_NAME"
    if [[ -f "$ENTITLEMENTS" ]]; then
        codesign --force --options runtime --entitlements "$ENTITLEMENTS" --sign "$identity" "$executable"
    else
        codesign --force --options runtime --sign "$identity" "$executable"
    fi
    codesign --force --options runtime --sign "$identity" "$app"
}

echo "▸ Cleaning previous artifacts…"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$STAGING_DIR"

echo "▸ Clearing extended attributes (required for codesign)…"
xattr -cr "$ROOT_DIR" 2>/dev/null || true
dot_clean -m "$ROOT_DIR/Clip Board Pro" 2>/dev/null || true

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

OAUTH_PLIST="$ROOT_DIR/Clip Board Pro/OAuth-Info.plist"
OAUTH_EXAMPLE="$ROOT_DIR/Clip Board Pro/OAuth-Info.plist.example"
if [[ ! -f "$OAUTH_PLIST" && -f "$OAUTH_EXAMPLE" ]]; then
    cp "$OAUTH_EXAMPLE" "$OAUTH_PLIST"
    echo "▸ Created OAuth-Info.plist from example (add Google keys in Settings for sync)."
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
    CODE_SIGNING_ALLOWED=NO \
    build

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"
SIGN_WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/clipboard-pro-sign.XXXXXX")
SANITIZED_APP="$SIGN_WORK_DIR/$APP_NAME.app"
rm -rf "$SANITIZED_APP"
echo "▸ Preparing app for signing (outside Desktop)…"
ditto --norsrc "$APP_PATH" "$SANITIZED_APP"
xattr -cr "$SANITIZED_APP" 2>/dev/null || true
APP_PATH="$SANITIZED_APP"
trap 'rm -rf "$SIGN_WORK_DIR"' EXIT

if [[ ! -d "$APP_PATH" ]]; then
    echo "Error: Built app not found at $APP_PATH"
    exit 1
fi

echo "▸ Verifying release bundle…"
if [[ ! -f "$APP_PATH/Contents/Resources/OAuth-Info.plist" ]]; then
    echo "Error: OAuth-Info.plist is missing from the app bundle."
    echo "Copy Clip Board Pro/OAuth-Info.plist.example to OAuth-Info.plist and add your Google credentials."
    exit 1
fi
if ! /usr/libexec/PlistBuddy -c "Print :GoogleOAuthClientID" "$APP_PATH/Contents/Resources/OAuth-Info.plist" 2>/dev/null | grep -q "apps.googleusercontent.com"; then
    echo "Warning: GoogleOAuthClientID may be missing or invalid in OAuth-Info.plist."
fi
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true

echo "▸ Code signing app…"
SIGN_IDENTITY=$(resolve_sign_identity)
if [[ "$USE_DEV_ID" == true && -z "$SIGN_IDENTITY" ]]; then
    echo "Error: No Developer ID Application certificate found in Keychain."
    exit 1
fi
if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "Error: Apple Development certificate required (sign in to Xcode with Apple ID)."
    exit 1
fi
echo "   Identity: $SIGN_IDENTITY"
sign_app_bundle "$APP_PATH" "$SIGN_IDENTITY"
codesign --verify --verbose=2 "$APP_PATH"

echo "▸ Smoke test (launch)…"
"$APP_PATH/Contents/MacOS/$APP_NAME" &
LAUNCH_PID=$!
sleep 1
if ! kill -0 "$LAUNCH_PID" 2>/dev/null; then
    echo "Error: App exited immediately (codesign / Sparkle). Use Xcode Apple ID signing and rebuild."
    exit 1
fi
kill "$LAUNCH_PID" 2>/dev/null || true
wait "$LAUNCH_PID" 2>/dev/null || true

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

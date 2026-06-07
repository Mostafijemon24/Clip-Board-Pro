#!/usr/bin/env bash
# Fix "Unverified" / won't open after downloading ClipBoard Pro on macOS.
set -euo pipefail

resolve_app_path() {
  if [[ -n "${1:-}" ]]; then
    echo "$1"
    return
  fi

  local script_dir repo_root
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  repo_root="$(cd "$script_dir/.." && pwd)"

  local candidates=(
    "/Applications/ClipBoard Pro.app"
    "$HOME/Applications/ClipBoard Pro.app"
    "$repo_root/release/mac-arm64/ClipBoard Pro.app"
    "$repo_root/release/mac/ClipBoard Pro.app"
  )

  # When bundled inside .app/Contents/Resources
  if [[ "$script_dir" == *"/Contents/Resources" ]]; then
    candidates+=("$(cd "$script_dir/../.." && pwd)")
  fi

  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate/Contents/MacOS" ]]; then
      echo "$candidate"
      return
    fi
  done

  echo ""
}

APP_PATH="$(resolve_app_path "${1:-}")"

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "ClipBoard Pro.app খুঁজে পাওয়া যায়নি।"
  echo 'Usage: bash fix-gatekeeper.sh "/Applications/ClipBoard Pro.app"'
  exit 1
fi

ENTITLEMENTS="$APP_PATH/Contents/Resources/entitlements.mac.plist"
SIGN_ARGS=(--force --sign - --timestamp=none)

echo "▶ Fixing Gatekeeper for: $APP_PATH"
echo "  (quarantine সরানো + ad-hoc sign)"

xattr -cr "$APP_PATH"

while IFS= read -r -d '' target; do
  args=("${SIGN_ARGS[@]}")
  if [[ "$target" == *.app && -f "$ENTITLEMENTS" ]]; then
    args+=(--options runtime --entitlements "$ENTITLEMENTS")
  fi
  args+=("$target")
  codesign "${args[@]}"
done < <(find "$APP_PATH/Contents" \( -type f -perm +111 -o -name "*.dylib" \) -print0 2>/dev/null | while IFS= read -r -d '' f; do
  file -b "$f" | grep -q "Mach-O" && printf '%s\0' "$f"
done)

while IFS= read -r -d '' bundle; do
  args=("${SIGN_ARGS[@]}")
  if [[ "$bundle" == *.app && -f "$ENTITLEMENTS" ]]; then
    args+=(--options runtime --entitlements "$ENTITLEMENTS")
  fi
  args+=("$bundle")
  codesign "${args[@]}"
done < <(find "$APP_PATH/Contents" \( -name "*.app" -o -name "*.framework" \) -print0)

root_args=("${SIGN_ARGS[@]}")
if [[ -f "$ENTITLEMENTS" ]]; then
  root_args+=(--options runtime --entitlements "$ENTITLEMENTS")
fi
root_args+=("$APP_PATH")
codesign "${root_args[@]}"
codesign --verify --deep --strict "$APP_PATH"

echo ""
echo "▶ Opening ClipBoard Pro..."
open "$APP_PATH"

echo ""
echo "যদি এখনও খুলতে না পারেন:"
echo "  1. System Settings → Privacy & Security → নিচে scroll করুন"
echo "  2. Security-তে \"ClipBoard Pro\"-এর পাশে \"Open Anyway\" চাপুন"
echo "  3. Accessibility permission allow করুন (auto-paste-এর জন্য)"

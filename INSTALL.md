# Clip Board Pro — Install (macOS)

## Final build (DMG)

From the project folder:

```bash
chmod +x build_dmg.sh
./build_dmg.sh
```

Output:

| Artifact | Path |
|----------|------|
| **Installer DMG** | `build/Install_ClipboardManager.dmg` |
| **App bundle** | `build/DerivedData/Build/Products/Release/Clip Board Pro.app` |

With an Apple **Developer ID** certificate:

```bash
./build_dmg.sh --dev-id
```

## Install on your Mac

1. Open `build/Install_ClipboardManager.dmg`.
2. Drag **Clip Board Pro** into **Applications**.
3. Launch from Applications (menu bar icon appears).
4. Grant **Accessibility** when prompted (required for ⌘⇧V and auto-paste).
5. Optional: **Settings → Account → Connect Google Account** for pinned-item sync (up to 50 pins).

## Before you build

- `Clip Board Pro/OAuth-Info.plist` must exist (copy from `OAuth-Info.plist.example` and add Google Client ID + Secret). This file is gitignored.
- Google Cloud: redirect URI `http://127.0.0.1:8765/oauth2callback`, Drive API enabled, test user added if app is in Testing mode.

## Distribution (Sparkle updates)

1. Host `release/appcast.xml` and the DMG on HTTPS.
2. Set `SUFeedURL` and `SUPublicEDKey` in the Xcode target (replace example URLs/keys).
3. Sign the DMG with Sparkle’s `sign_update` and update the appcast `enclosure` signature.

## Version

Current release: **1.0** (build **1**), macOS **13.0+**.

## App does not open when clicked?

**Crash fix:** Rebuild with `./build_dmg.sh` after signing in to Xcode with your Apple ID (**Apple Development** certificate). Ad-hoc DMG builds can fail to load Sparkle and exit instantly.

**Menu bar app:** Clip Board Pro does not show a normal window. Look for the **clipboard** icon at the **top-right of the menu bar**, or press **⌘⇧V**. Right-click the icon for Settings.

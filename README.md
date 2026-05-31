# Clip Board Pro

Premium macOS menu bar clipboard manager: history, images, pins, global shortcut **⌘⇧V**, auto-paste, and optional **Google Drive** sync for pinned items.

## Quick install (recommended)

1. Open **[Releases](https://github.com/Mostafijemon24/Clip-Board-Pro/releases)** and download **`Install_ClipboardManager.dmg`** (latest).
2. Open the DMG and drag **Clip Board Pro** into **Applications**.
3. Launch from Applications. Grant **Accessibility** when asked.
4. Use the **clipboard** icon in the **menu bar** (top-right) or press **⌘⇧V**.

> This app is a **menu bar app** — it does not show a normal Dock window. Look for the icon in the menu bar.

## Build from source (ZIP / clone)

**Requirements:** macOS 13+, [Xcode](https://developer.apple.com/xcode/), [Homebrew](https://brew.sh/) optional for `create-dmg`.

```bash
# 1. Get the code
git clone https://github.com/Mostafijemon24/Clip-Board-Pro.git
cd Clip-Board-Pro

# 2. Install DMG tool (once)
brew install create-dmg

# 3. Sign in to Xcode with your Apple ID (Settings → Accounts)
#    so "Apple Development" certificate exists for codesign.

# 4. Build installer
chmod +x build_dmg.sh
./build_dmg.sh
```

**Output:** `build/Install_ClipboardManager.dmg` — open it and install to Applications.

See **[INSTALL.md](INSTALL.md)** for troubleshooting (app won’t open, codesign, Gatekeeper).

### Google account sync (optional)

1. Copy the example plist if you build from a fresh ZIP without `OAuth-Info.plist`:
   ```bash
   cp "Clip Board Pro/OAuth-Info.plist.example" "Clip Board Pro/OAuth-Info.plist"
   ```
2. Add your [Google Cloud OAuth](https://console.cloud.google.com/) **Client ID** and **Secret** (Web application).
3. Redirect URI: `http://127.0.0.1:8765/oauth2callback`
4. Rebuild with `./build_dmg.sh`.
5. In the app: **Settings → Account → Connect Google Account**.

`OAuth-Info.plist` is **gitignored** — never commit real secrets.

## Features

- Clipboard history (text, images on disk — not held in RAM)
- Security filter (password managers, banking apps ignored)
- Pin up to **50** items; **Clear All** keeps pinned
- Global shortcut **⌘⇧V** and optional auto-paste
- Google Drive sync for **pinned** items only
- Sparkle-ready update plumbing (`release/appcast.xml`)

## Project layout

| Path | Purpose |
|------|---------|
| `Clip Board Pro/` | Swift source, assets, entitlements |
| `build_dmg.sh` | Release build + DMG |
| `INSTALL.md` | Install & troubleshooting |
| `release/appcast.xml` | Sparkle appcast template |

## License

Copyright © Mostafij Emon. All rights reserved unless you add a license file.

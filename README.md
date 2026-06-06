# Clip Board Pro

**Premium macOS clipboard manager** — history, pins, emoji/GIF picker, snippets, global shortcut, and auto-paste into any app.

[![Release](https://img.shields.io/github/v/release/Mostafijemon24/Clip-Board-Pro)](https://github.com/Mostafijemon24/Clip-Board-Pro/releases)
[![Platform](https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon)-blue)](https://github.com/Mostafijemon24/Clip-Board-Pro/releases)
[![License](https://img.shields.io/badge/license-MIT-lightgrey)](#license)

---

## বাংলায় দ্রুত শুরু

1. **[Releases](https://github.com/Mostafijemon24/Clip-Board-Pro/releases)** থেকে `Clip Board Pro-1.1.0-arm64.dmg` ডাউনলোড করুন।
2. DMG খুলে **Applications** ফোল্ডারে অ্যাপ টেনে রাখুন।
3. প্রথমবার **Right-click → Open** দিয়ে চালু করুন (unsigned build)।
4. **System Settings → Privacy & Security → Accessibility**-তে `Clip Board Pro` allow করুন।
5. যেকোনো জায়গায় **`⌃⌘V`** (Control + Command + V) চাপুন — cursor-এ popup খুলবে।
6. কোনো item ক্লিক করলে সেটা স্বয়ংক্রিয়ভাবে editor-এ paste হবে।

> এটি **menu bar app** — Dock-এ আইকন দেখা নাও যেতে পারে। Menu bar-এর clipboard icon বা shortcut ব্যবহার করুন।

---

## Download (macOS Apple Silicon)

| File | Description |
|------|-------------|
| [**DMG Installer**](https://github.com/Mostafijemon24/Clip-Board-Pro/releases/latest/download/Clip.Board.Pro-1.1.0-arm64.dmg) | Recommended — drag to Applications |
| [**ZIP Archive**](https://github.com/Mostafijemon24/Clip-Board-Pro/releases/latest/download/Clip.Board.Pro-1.1.0-arm64-mac.zip) | Portable `.app` bundle |

> Requires **macOS 12+** on **Apple Silicon (M1/M2/M3)**. Intel Mac support may be added in a future release.

---

## Features

### Clipboard
- **Live clipboard capture** — text, images, and file names auto-saved
- **Image thumbnails** — copied images show as small previews
- **Pin items** — pinned clips stay until you unpin them
- **Archive & delete** — three-dot menu on each item
- **Clear all** — remove unpinned history in one click

### Clipboard History Modes
| Mode | Behavior |
|------|----------|
| **History ON** | Unpinned items kept **24 hours**; pinned items kept **forever** |
| **History OFF** | Unpinned items kept **1 hour** (session); auto-deleted after |

### Popup & Shortcut
- **Default shortcut:** `⌃⌘V` (Control + Command + V)
- Popup opens **at your mouse cursor**
- Click any item → **auto-paste** into the last active text field
- Shortcut is **customizable** in Settings and saved permanently

### Content Pickers
- **Emoji** — full emoji library with search & categories
- **GIFs** — Tenor-powered search & trending (fast static previews)
- **Special Characters** — currency, math, arrows, Greek, shapes, etc.
- **Text Snippets** — notepad-style notes saved in local storage

### macOS Integration
- **Menu bar tray icon** — click to open popup
- **Background clipboard monitoring** — works even when popup is closed
- **No Dock icon** — stays out of the way (LSUIElement)

---

## Screenshots & Usage

```
1. Copy anything on your Mac (text, image, code)
2. Press ⌃⌘V anywhere
3. Popup appears above your cursor
4. Click an item → it pastes into your editor automatically
```

### Changing the Shortcut
1. Open popup → **Settings** tab
2. Scroll to **Popup Shortcut**
3. Click the shortcut box → press your new key combination
4. Click **Save Shortcut**

---

## Build from Source

### Requirements
- macOS 12+
- [Node.js](https://nodejs.org/) 20+
- npm 9+

### Install dependencies

```bash
git clone https://github.com/Mostafijemon24/Clip-Board-Pro.git
cd Clip-Board-Pro
npm install
```

> If `npm install` times out, run:
> ```bash
> npm config set fetch-timeout 300000
> npm config set fetch-retries 5
> node scripts/fix-electron.js
> ```

### Development (hot reload)

```bash
npm run electron:dev
```

This starts Vite + Electron. Use `⌃⌘V` to test the popup.

### Production build

```bash
npm run electron:build
```

**Output:**
```
release/Clip Board Pro-1.1.0-arm64.dmg
release/Clip Board Pro-1.1.0-arm64-mac.zip
release/mac-arm64/Clip Board Pro.app
```

### Web-only dev (browser)

```bash
npm run dev
# → http://localhost:5173
```

---

## Project Structure

```
Clip Board Pro/
├── electron/
│   ├── main.cjs          # Electron main process (tray, shortcut, clipboard)
│   └── preload.cjs       # Secure IPC bridge
├── src/
│   ├── App.tsx           # Main UI & clipboard logic
│   ├── components/       # EmojiPicker, GifPicker, SpecialCharPicker, etc.
│   └── lib/              # Utilities
├── scripts/
│   ├── electron-dev.sh   # Dev launcher
│   ├── fix-electron.js   # Fixes incomplete Electron binary installs
│   └── create-icons.js   # App & tray icons
├── build/
│   └── entitlements.mac.plist
└── package.json
```

---

## Permissions

| Permission | Why |
|------------|-----|
| **Accessibility** | Required to simulate `⌘V` paste into other apps |
| **Clipboard** | Read copied text and images for history |

Grant in: **System Settings → Privacy & Security → Accessibility**

---

## Troubleshooting

### App won't open (Gatekeeper)
Right-click the app → **Open** → confirm. Unsigned local builds trigger this warning.

### `Electron failed to install` / `Framework not loaded`
```bash
node scripts/fix-electron.js
npm run electron:dev
```

### `npm install` network timeout
```bash
npm config set fetch-timeout 300000
npm install --registry https://registry.npmmirror.com
node scripts/fix-electron.js
```

### Auto-paste not working
1. Check **Accessibility** permission is granted
2. Click into a text field first, then open popup and select an item
3. Restart the app after granting permission

### GIFs not loading (dev mode)
Vite proxy handles CORS in dev. In production Electron fetches Tenor API directly.

---

## Tech Stack

| Layer | Technology |
|-------|------------|
| UI | React 19 + TypeScript |
| Styling | Tailwind CSS 4 |
| Desktop | Electron 35 |
| Build | Vite 6 + electron-builder |
| GIFs | Tenor API |
| Emojis | emoji-mart |

---

## Changelog

### v1.1.0 (2026-06-06)
- Full **Electron + React** rewrite with modern UI
- Global shortcut `⌃⌘V` with cursor-position popup
- Auto-paste into any macOS app
- Clipboard history with 24h / 1h retention modes
- Pin / archive / delete management
- Emoji, GIF, special character, and snippet pickers
- Customizable & persistent keyboard shortcut
- Menu bar tray integration
- Background clipboard monitoring

### v1.0.0
- Initial Swift / native macOS version (legacy)

---

## License

MIT © [Mostafij Emon](https://github.com/Mostafijemon24)

---

## Links

- **Releases:** https://github.com/Mostafijemon24/Clip-Board-Pro/releases
- **Issues:** https://github.com/Mostafijemon24/Clip-Board-Pro/issues
- **Repository:** https://github.com/Mostafijemon24/Clip-Board-Pro

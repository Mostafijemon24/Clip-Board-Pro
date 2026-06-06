const {
  app,
  BrowserWindow,
  globalShortcut,
  screen,
  Tray,
  Menu,
  ipcMain,
  clipboard,
  nativeImage,
} = require("electron");
const path = require("path");
const { exec } = require("child_process");

const isDev = !app.isPackaged;
const POPUP_W = 400;
const POPUP_H = 560;
const PAD = 10;

let mainWindow = null;
let tray = null;
let currentShortcut = null;
let lastClipboardKey = "";

function getPreloadPath() {
  return path.join(__dirname, "preload.cjs");
}

function shortcutToAccelerator(config) {
  const parts = [];
  if (config.ctrl) parts.push("Control");
  if (config.alt) parts.push("Alt");
  if (config.shift) parts.push("Shift");
  if (config.meta) parts.push("Command");
  parts.push(config.key.length === 1 ? config.key.toUpperCase() : config.key);
  return parts.join("+");
}

function registerGlobalShortcut(config) {
  if (currentShortcut) {
    globalShortcut.unregister(currentShortcut);
    currentShortcut = null;
  }
  const accelerator = shortcutToAccelerator(config);
  const ok = globalShortcut.register(accelerator, () => togglePopup());
  if (ok) currentShortcut = accelerator;
  return ok;
}

function clampPopupPosition(x, y) {
  const display = screen.getDisplayNearestPoint({ x, y });
  const area = display.workArea;

  let posX = x - POPUP_W / 2;
  let posY = y - POPUP_H - 12;

  if (posX + POPUP_W > area.x + area.width - PAD) {
    posX = area.x + area.width - POPUP_W - PAD;
  }
  if (posX < area.x + PAD) posX = area.x + PAD;
  if (posY < area.y + PAD) posY = y + 20;
  if (posY + POPUP_H > area.y + area.height - PAD) {
    posY = area.y + area.height - POPUP_H - PAD;
  }

  return { x: Math.round(posX), y: Math.round(posY) };
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: POPUP_W,
    height: POPUP_H,
    show: false,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    hasShadow: true,
    vibrancy: "under-window",
    visualEffectState: "active",
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  if (isDev) {
    mainWindow.loadURL("http://localhost:5173");
  } else {
    mainWindow.loadFile(path.join(__dirname, "../dist/index.html"));
  }

  mainWindow.on("blur", () => {
    if (mainWindow && !mainWindow.isDestroyed() && mainWindow.isVisible()) {
      mainWindow.hide();
      mainWindow.webContents.send("popup-hidden");
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

function togglePopup() {
  if (!mainWindow) return;

  if (mainWindow.isVisible()) {
    mainWindow.hide();
    mainWindow.webContents.send("popup-hidden");
    return;
  }

  const cursor = screen.getCursorScreenPoint();
  const { x, y } = clampPopupPosition(cursor.x, cursor.y);
  mainWindow.setBounds({ x, y, width: POPUP_W, height: POPUP_H });
  mainWindow.show();
  mainWindow.focus();
  mainWindow.webContents.send("popup-shown", { x: cursor.x, y: cursor.y });
}

function simulatePaste() {
  exec(
    `osascript -e 'tell application "System Events" to keystroke "v" using command down'`,
    () => {}
  );
}

function createTray() {
  const iconPath = path.join(__dirname, "../build/trayTemplate.png");
  let icon;
  try {
    icon = nativeImage.createFromPath(iconPath);
    icon.setTemplateImage(true);
  } catch {
    icon = nativeImage.createEmpty();
  }

  tray = new Tray(icon.isEmpty() ? nativeImage.createFromDataURL(
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAAOCAYAAAAfSC3RAAAAFUlEQVR42mP8z8BQz0AEYBxVSF+FABJADveWkH6aAAAAAElFTkSuQmCC"
  ) : icon);

  const menu = Menu.buildFromTemplate([
    {
      label: "Open Clipboard",
      click: () => togglePopup(),
    },
    { type: "separator" },
    {
      label: "Quit ClipBoard Pro",
      click: () => app.quit(),
    },
  ]);

  tray.setToolTip("ClipBoard Pro");
  tray.setContextMenu(menu);
  tray.on("click", () => togglePopup());
}

function pollClipboard() {
  if (!mainWindow || mainWindow.isDestroyed()) return;

  try {
    const formats = clipboard.availableFormats();
    const imageFormat = formats.find((f) => f.startsWith("image/"));

    if (imageFormat) {
      const image = clipboard.readImage();
      if (!image.isEmpty()) {
        const png = image.toPNG();
        const key = `img:${png.length}:${png.slice(0, 32).toString("hex")}`;
        if (key !== lastClipboardKey) {
          lastClipboardKey = key;
          const dataUrl = `data:image/png;base64,${png.toString("base64")}`;
          mainWindow.webContents.send("clipboard-image", { dataUrl, filename: "image.png" });
        }
        return;
      }
    }

    const text = clipboard.readText();
    if (text && text !== lastClipboardKey) {
      lastClipboardKey = text;
      mainWindow.webContents.send("clipboard-text", { text });
    }
  } catch {
    /* ignore clipboard read errors */
  }
}

function setupIpc() {
  ipcMain.handle("register-shortcut", (_, config) => registerGlobalShortcut(config));

  ipcMain.handle("hide-popup", () => {
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.hide();
      mainWindow.webContents.send("popup-hidden");
    }
  });

  ipcMain.handle("show-popup", () => {
    togglePopup();
  });

  ipcMain.handle("paste-text", async (_, text) => {
    clipboard.writeText(text);
    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.hide();
      mainWindow.webContents.send("popup-hidden");
    }
    await new Promise((r) => setTimeout(r, 120));
    simulatePaste();
  });

  ipcMain.handle("paste-image", async (_, dataUrl) => {
    try {
      const base64 = dataUrl.replace(/^data:image\/\w+;base64,/, "");
      const buffer = Buffer.from(base64, "base64");
      const image = nativeImage.createFromBuffer(buffer);
      clipboard.writeImage(image);
      if (mainWindow && !mainWindow.isDestroyed()) {
        mainWindow.hide();
        mainWindow.webContents.send("popup-hidden");
      }
      await new Promise((r) => setTimeout(r, 120));
      simulatePaste();
    } catch {
      clipboard.writeText(dataUrl);
      simulatePaste();
    }
  });

  ipcMain.handle("get-cursor-point", () => screen.getCursorScreenPoint());
  ipcMain.handle("is-electron", () => true);
}

app.whenReady().then(() => {
  if (process.platform === "darwin" && app.dock) {
    app.dock.hide();
  }

  createWindow();
  createTray();
  setupIpc();

  registerGlobalShortcut({ ctrl: true, meta: true, alt: false, shift: false, key: "V" });

  setInterval(pollClipboard, 600);

  app.on("activate", () => {
    if (!mainWindow) createWindow();
  });
});

app.on("will-quit", () => {
  globalShortcut.unregisterAll();
});

app.on("window-all-closed", (e) => {
  e.preventDefault();
});

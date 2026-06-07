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
  systemPreferences,
  shell,
} = require("electron");
const path = require("path");
const { exec, execFileSync } = require("child_process");

const isDev = !app.isPackaged;
const POPUP_W = 400;
const POPUP_H = 560;
const PAD = 10;
const OFFSCREEN = { x: -10000, y: -10000 };

let mainWindow = null;
let tray = null;
let currentShortcut = null;
let lastClipboardKey = "";
let targetAppForPaste = null;
let targetAppPid = null;
let targetAppBundleId = null;
let lastExternalApp = null;
let lastExternalPid = null;
let lastExternalBundleId = null;
let lastTargetClickPoint = null;
let isPasting = false;
let blurHideTimer = null;

const OWN_APPS = new Set(["ClipBoard Pro", "Electron"]);

function accessibilityAppLabel() {
  return isDev ? "Electron" : "ClipBoard Pro";
}

function runAppleScript(script) {
  return new Promise((resolve) => {
    exec(`osascript -e ${JSON.stringify(script)}`, (err, stdout) => {
      resolve({ err, stdout: stdout?.trim() ?? "" });
    });
  });
}

function escapeAppleScriptString(value) {
  return value.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
}

function isOwnApp(name) {
  return !name || OWN_APPS.has(name);
}

function rememberExternalApp(name, pid, bundleId) {
  if (!name || isOwnApp(name)) return;
  lastExternalApp = name;
  lastExternalPid = pid;
  lastExternalBundleId = bundleId;
}

function getFrontmostAppSync() {
  try {
    const asnLine = execFileSync("lsappinfo", ["front"], { encoding: "utf8" }).trim().split("\n")[0];
    const asn = asnLine?.trim();
    if (!asn) return null;

    const info = execFileSync("lsappinfo", ["info", "-only", "name,pid,bundleID", asn], {
      encoding: "utf8",
    });

    const name = info.match(/"LSDisplayName"="([^"]+)"/)?.[1] ?? null;
    const pid = Number.parseInt(info.match(/"pid"=(\d+)/)?.[1] ?? "", 10);
    const bundleId = info.match(/"CFBundleIdentifier"="([^"]+)"/)?.[1] ?? null;

    if (!name || isOwnApp(name)) return null;

    return {
      name,
      pid: Number.isFinite(pid) ? pid : null,
      bundleId,
    };
  } catch {
    return null;
  }
}

function refreshFrontmostAppSync() {
  const current = getFrontmostAppSync();
  if (current) {
    rememberExternalApp(current.name, current.pid, current.bundleId);
    return current;
  }
  return null;
}

function rememberTargetApp(appInfo) {
  if (!appInfo) return;
  targetAppForPaste = appInfo.name;
  targetAppPid = appInfo.pid;
  targetAppBundleId = appInfo.bundleId;
}

function rememberTargetFromLastExternal() {
  if (!lastExternalApp) return;
  targetAppForPaste = lastExternalApp;
  targetAppPid = lastExternalPid;
  targetAppBundleId = lastExternalBundleId;
}

function captureTargetForPopup() {
  const current = refreshFrontmostAppSync();
  if (current) {
    rememberTargetApp(current);
  } else {
    rememberTargetFromLastExternal();
  }
  lastTargetClickPoint = screen.getCursorScreenPoint();
}

function hasAccessibilityPermission(prompt = false) {
  if (process.platform !== "darwin") return true;
  return systemPreferences.isTrustedAccessibilityClient(prompt);
}

function openAccessibilitySettings() {
  void shell.openExternal(
    "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
  );
}

function activateTargetApp(targetName, targetBundleId) {
  try {
    if (targetBundleId) {
      execFileSync("open", ["-b", targetBundleId]);
      return;
    }
    if (targetName) {
      execFileSync("open", ["-a", targetName]);
    }
  } catch {
    /* ignore activation errors */
  }
}

async function pasteIntoTargetApp() {
  const targetName = targetAppForPaste || lastExternalApp;
  const targetBundleId = targetAppBundleId || lastExternalBundleId;
  const clickPoint = lastTargetClickPoint;

  if (!hasAccessibilityPermission(true)) {
    return {
      ok: false,
      needsAccessibility: true,
      error: `${accessibilityAppLabel()} needs Accessibility permission to auto-paste.`,
    };
  }

  hidePopup();
  if (process.platform === "darwin") {
    app.hide();
  }

  await new Promise((r) => setTimeout(r, 120));

  activateTargetApp(targetName, targetBundleId);
  await new Promise((r) => setTimeout(r, 350));

  const x = clickPoint?.x ?? null;
  const y = clickPoint?.y ?? null;
  let pasteErr = null;

  if (x != null && y != null) {
    const { err } = await runAppleScript(`
      tell application "System Events"
        click at {${Math.round(x)}, ${Math.round(y)}}
        delay 0.12
        keystroke "v" using command down
      end tell
    `);
    pasteErr = err;
  }

  if (pasteErr && targetName) {
    const name = escapeAppleScriptString(targetName);
    const { err } = await runAppleScript(`
      tell application "System Events"
        tell process "${name}"
          set frontmost to true
        end tell
        delay 0.2
        keystroke "v" using command down
      end tell
    `);
    pasteErr = err;
  }

  if (pasteErr && !targetName) {
    const { err } = await runAppleScript(
      'tell application "System Events" to keystroke "v" using command down'
    );
    pasteErr = err;
  }

  if (pasteErr) {
    const msg = pasteErr.message || String(pasteErr);
    if (msg.includes("1002") || msg.includes("not allowed")) {
      return {
        ok: false,
        needsAccessibility: true,
        error: `Allow ${accessibilityAppLabel()} in System Settings → Privacy & Security → Accessibility, then restart the app.`,
      };
    }
    return { ok: false, error: msg };
  }

  return { ok: true };
}

function hidePopup() {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.setPosition(OFFSCREEN.x, OFFSCREEN.y);
    mainWindow.hide();
    mainWindow.webContents.send("popup-hidden");
  }
}

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
  const ok = globalShortcut.register(accelerator, () => {
    captureTargetForPopup();
    void togglePopup();
  });
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
    backgroundColor: "#00000000",
    alwaysOnTop: true,
    skipTaskbar: true,
    resizable: false,
    hasShadow: true,
    focusable: true,
    webPreferences: {
      preload: getPreloadPath(),
      contextIsolation: true,
      nodeIntegration: false,
      sandbox: false,
    },
  });

  mainWindow.setPosition(OFFSCREEN.x, OFFSCREEN.y);
  mainWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });

  if (isDev) {
    mainWindow.loadURL("http://localhost:5173");
  } else {
    mainWindow.loadFile(path.join(__dirname, "../dist/index.html"));
  }

  mainWindow.on("blur", () => {
    if (blurHideTimer) clearTimeout(blurHideTimer);
    blurHideTimer = setTimeout(() => {
      blurHideTimer = null;
      if (isPasting) return;
      hidePopup();
    }, 150);
  });

  mainWindow.on("focus", () => {
    if (blurHideTimer) {
      clearTimeout(blurHideTimer);
      blurHideTimer = null;
    }
  });

  mainWindow.on("closed", () => {
    mainWindow = null;
  });
}

async function togglePopup() {
  if (!mainWindow) return;

  if (mainWindow.isVisible()) {
    hidePopup();
    return;
  }

  captureTargetForPopup();

  const cursor = screen.getCursorScreenPoint();
  const { x, y } = clampPopupPosition(cursor.x, cursor.y);
  mainWindow.setBounds({ x, y, width: POPUP_W, height: POPUP_H });
  mainWindow.showInactive();
  mainWindow.webContents.send("popup-shown", { x: cursor.x, y: cursor.y });
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
      click: () => {
        rememberTargetFromLastExternal();
        lastTargetClickPoint = screen.getCursorScreenPoint();
        void togglePopup();
      },
    },
    { type: "separator" },
    {
      label: "Quit ClipBoard Pro",
      click: () => app.quit(),
    },
  ]);

  tray.setToolTip("ClipBoard Pro");
  tray.setContextMenu(menu);
  tray.on("click", () => {
    rememberTargetFromLastExternal();
    lastTargetClickPoint = screen.getCursorScreenPoint();
    void togglePopup();
  });
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

async function performPaste(writeFn) {
  isPasting = true;
  if (blurHideTimer) {
    clearTimeout(blurHideTimer);
    blurHideTimer = null;
  }
  try {
    writeFn();
    return await pasteIntoTargetApp();
  } finally {
    isPasting = false;
  }
}

function setupIpc() {
  ipcMain.handle("register-shortcut", (_, config) => registerGlobalShortcut(config));

  ipcMain.handle("hide-popup", () => {
    hidePopup();
  });

  ipcMain.handle("show-popup", () => {
    void togglePopup();
  });

  ipcMain.handle("prepare-paste", () => {
    isPasting = true;
    if (blurHideTimer) {
      clearTimeout(blurHideTimer);
      blurHideTimer = null;
    }
  });

  ipcMain.handle("check-accessibility", () => ({
    granted: hasAccessibilityPermission(false),
    appName: accessibilityAppLabel(),
  }));

  ipcMain.handle("open-accessibility-settings", () => {
    openAccessibilitySettings();
  });

  ipcMain.handle("paste-text", async (_, text) => performPaste(() => clipboard.writeText(text)));

  ipcMain.handle("paste-image", async (_, dataUrl) => {
    try {
      return await performPaste(() => {
        const base64 = dataUrl.replace(/^data:image\/\w+;base64,/, "");
        const buffer = Buffer.from(base64, "base64");
        const image = nativeImage.createFromBuffer(buffer);
        clipboard.writeImage(image);
      });
    } catch {
      return performPaste(() => clipboard.writeText(dataUrl));
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
  setInterval(() => {
    refreshFrontmostAppSync();
  }, 200);

  setTimeout(() => {
    if (!hasAccessibilityPermission(false)) {
      hasAccessibilityPermission(true);
    }
  }, 1500);

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

const { contextBridge, ipcRenderer } = require("electron");

contextBridge.exposeInMainWorld("electronAPI", {
  isElectron: true,
  registerShortcut: (config) => ipcRenderer.invoke("register-shortcut", config),
  hidePopup: () => ipcRenderer.invoke("hide-popup"),
  showPopup: () => ipcRenderer.invoke("show-popup"),
  preparePaste: () => ipcRenderer.invoke("prepare-paste"),
  pasteText: (text) => ipcRenderer.invoke("paste-text", text),
  pasteImage: (dataUrl) => ipcRenderer.invoke("paste-image", dataUrl),
  checkAccessibility: () => ipcRenderer.invoke("check-accessibility"),
  openAccessibilitySettings: () => ipcRenderer.invoke("open-accessibility-settings"),
  getCursorPoint: () => ipcRenderer.invoke("get-cursor-point"),
  onPopupShown: (cb) => {
    const handler = (_, data) => cb(data);
    ipcRenderer.on("popup-shown", handler);
    return () => ipcRenderer.removeListener("popup-shown", handler);
  },
  onPopupHidden: (cb) => {
    const handler = () => cb();
    ipcRenderer.on("popup-hidden", handler);
    return () => ipcRenderer.removeListener("popup-hidden", handler);
  },
  onClipboardText: (cb) => {
    const handler = (_, data) => cb(data);
    ipcRenderer.on("clipboard-text", handler);
    return () => ipcRenderer.removeListener("clipboard-text", handler);
  },
  onClipboardImage: (cb) => {
    const handler = (_, data) => cb(data);
    ipcRenderer.on("clipboard-image", handler);
    return () => ipcRenderer.removeListener("clipboard-image", handler);
  },
});

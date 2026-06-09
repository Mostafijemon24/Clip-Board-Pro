export interface ShortcutConfig {
  ctrl: boolean;
  meta: boolean;
  alt: boolean;
  shift: boolean;
  key: string;
}

export interface PasteResult {
  ok: boolean;
  error?: string;
  needsAccessibility?: boolean;
}

export interface AccessibilityStatus {
  granted: boolean;
  appName: string;
  appPath: string;
}

export interface ElectronAPI {
  isElectron: true;
  registerShortcut: (config: ShortcutConfig) => Promise<boolean>;
  hidePopup: () => Promise<void>;
  showPopup: () => Promise<void>;
  pasteText: (text: string) => Promise<PasteResult>;
  preparePaste: () => Promise<void>;
  pasteImage: (dataUrl: string) => Promise<PasteResult>;
  checkAccessibility: () => Promise<AccessibilityStatus>;
  openAccessibilitySettings: () => Promise<void>;
  getCursorPoint: () => Promise<{ x: number; y: number }>;
  getLaunchAtLogin: () => Promise<boolean>;
  setLaunchAtLogin: (enabled: boolean) => Promise<{ openAtLogin: boolean }>;
  onPopupShown: (cb: (data?: { x: number; y: number }) => void) => () => void;
  onPopupHidden: (cb: () => void) => () => void;
  onClipboardText: (cb: (data: { text: string }) => void) => () => void;
  onClipboardImage: (cb: (data: { dataUrl: string; filename?: string }) => void) => () => void;
}

declare global {
  interface Window {
    electronAPI?: ElectronAPI;
  }
}

export {};

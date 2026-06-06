export interface ShortcutConfig {
  ctrl: boolean;
  meta: boolean;
  alt: boolean;
  shift: boolean;
  key: string;
}

export interface ElectronAPI {
  isElectron: true;
  registerShortcut: (config: ShortcutConfig) => Promise<boolean>;
  hidePopup: () => Promise<void>;
  showPopup: () => Promise<void>;
  pasteText: (text: string) => Promise<void>;
  pasteImage: (dataUrl: string) => Promise<void>;
  getCursorPoint: () => Promise<{ x: number; y: number }>;
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

import { useState, useEffect, useRef, useCallback } from "react";
import {
  Archive,
  ClipboardList,
  Copy,
  Grid3x3,
  Hash,
  Heart,
  Image,
  Info,
  NotebookPen,
  Pin,
  PinOff,
  Settings,
  Smile,
  Trash2,
  Type,
  X,
} from "lucide-react";
import { Button } from "@/components/ui/button";
import EmojiPicker from "@/components/EmojiPicker";
import GifPicker from "@/components/GifPicker";
import SpecialCharPicker from "@/components/SpecialCharPicker";
import { isElectron } from "@/lib/isElectron";

/* ─── Text Snippet types ─── */
interface Snippet {
  id: string;
  label: string;
  value: string;
  createdAt: number;
}

const SNIPPETS_KEY = "cbp_snippets";

function loadSnippets(): Snippet[] {
  try {
    return JSON.parse(localStorage.getItem(SNIPPETS_KEY) ?? "[]");
  } catch {
    return [];
  }
}

function saveSnippets(snippets: Snippet[]) {
  localStorage.setItem(SNIPPETS_KEY, JSON.stringify(snippets));
}

type NavTab = "clipboard" | "emoji" | "more" | "settings";
type CategoryTab = "favorites" | "emoji" | "gifs" | "text" | "snippets" | "clipboard";

const IMAGE_EXTS   = /\.(jpe?g|png|gif|webp|bmp|svg|heic|avif|tiff?)$/i;
const HOUR_MS      = 60 * 60 * 1000;
const DAY_MS       = 24 * HOUR_MS;
const ITEMS_KEY    = "cbp_items";
const HISTORY_KEY  = "cbp_history";
const SHORTCUT_KEY = "cbp_shortcut";

/* ─── Shortcut ─── */
interface ShortcutConfig {
  ctrl:  boolean;
  meta:  boolean;   /* Cmd on Mac */
  alt:   boolean;
  shift: boolean;
  key:   string;    /* uppercase letter / key name */
}

const DEFAULT_SHORTCUT: ShortcutConfig = { ctrl: true, meta: true, alt: false, shift: false, key: "V" };

function loadShortcut(): ShortcutConfig {
  try {
    const raw = localStorage.getItem(SHORTCUT_KEY);
    return raw ? { ...DEFAULT_SHORTCUT, ...JSON.parse(raw) } : DEFAULT_SHORTCUT;
  } catch { return DEFAULT_SHORTCUT; }
}

function shortcutLabel(s: ShortcutConfig): string {
  const parts: string[] = [];
  if (s.ctrl)  parts.push("⌃");
  if (s.alt)   parts.push("⌥");
  if (s.shift) parts.push("⇧");
  if (s.meta)  parts.push("⌘");
  parts.push(s.key.toUpperCase());
  return parts.join("");
}

function matchesShortcut(e: KeyboardEvent, s: ShortcutConfig): boolean {
  return (
    e.ctrlKey  === s.ctrl  &&
    e.metaKey  === s.meta  &&
    e.altKey   === s.alt   &&
    e.shiftKey === s.shift &&
    e.key.toUpperCase() === s.key.toUpperCase()
  );
}

interface ClipItem {
  id: string;
  type: "text" | "image" | "file";
  value: string;
  filename?: string;
  pinned: boolean;
  archived: boolean;
  timestamp: number;
  expiresAt: number;   /* ms epoch — Infinity = never (pinned) */
}

function loadItems(): ClipItem[] {
  try {
    const raw = localStorage.getItem(ITEMS_KEY);
    if (!raw) return [];
    const items: ClipItem[] = JSON.parse(raw);
    const now = Date.now();
    /* Filter expired non-pinned items on load */
    return items.filter((i) => i.pinned || i.expiresAt > now);
  } catch { return []; }
}

function saveItems(items: ClipItem[]) {
  try {
    localStorage.setItem(ITEMS_KEY, JSON.stringify(items));
  } catch {
    /* Quota exceeded — save text only */
    try {
      const textOnly = items.filter((i) => i.type !== "image");
      localStorage.setItem(ITEMS_KEY, JSON.stringify(textOnly));
    } catch { /* give up */ }
  }
}

function loadHistoryOn(): boolean {
  return localStorage.getItem(HISTORY_KEY) !== "false";
}


/* ─── Three-dot dropdown ─── */
function ItemMenu({
  onArchive,
  onDelete,
}: {
  onArchive: () => void;
  onDelete: () => void;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handler(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, []);

  return (
    <div className="relative" ref={ref}>
      <button
        onClick={() => setOpen((o) => !o)}
        className="rounded-md p-1 hover:bg-neutral-200/60 transition-colors"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          className="text-neutral-500"
        >
          <circle cx="12" cy="5" r="1" /><circle cx="12" cy="12" r="1" /><circle cx="12" cy="19" r="1" />
        </svg>
      </button>
      {open && (
        <div className="absolute right-0 top-7 z-50 bg-white border border-neutral-200 rounded-xl shadow-lg overflow-hidden w-36">
          <button
            onClick={() => { onArchive(); setOpen(false); }}
            className="flex items-center gap-2 w-full px-3 py-2 text-sm text-neutral-700 hover:bg-neutral-100 transition-colors"
          >
            <Archive className="size-3.5 text-neutral-500" />
            Archive
          </button>
          <button
            onClick={() => { onDelete(); setOpen(false); }}
            className="flex items-center gap-2 w-full px-3 py-2 text-sm text-red-500 hover:bg-red-50 transition-colors"
          >
            <Trash2 className="size-3.5" />
            Delete
          </button>
        </div>
      )}
    </div>
  );
}

/* ─── Single clipboard row ─── */
function ClipRow({
  item,
  isSelected,
  onPin,
  onArchive,
  onDelete,
  onSelect,
  onPaste,
}: {
  item: ClipItem;
  isSelected?: boolean;
  onPin: () => void;
  onArchive: () => void;
  onDelete: () => void;
  onSelect?: (text: string) => void;
  onPaste?: (item: ClipItem) => void;
}) {
  const copyToClipboard = async () => {
    if (onPaste) {
      onPaste(item);
      return;
    }
    if (item.type === "text") {
      await navigator.clipboard.writeText(item.value);
      onSelect?.(item.value);
    } else {
      try {
        const res = await fetch(item.value);
        const blob = await res.blob();
        await navigator.clipboard.write([new ClipboardItem({ [blob.type]: blob })]);
      } catch {
        await navigator.clipboard.writeText(item.value);
      }
      onSelect?.("");
    }
  };

  const isImg  = item.type === "image";
  const isFile = item.type === "file";

  const handleRowActivate = (e: React.MouseEvent) => {
    if (e.button !== 0) return;
    if ((e.target as HTMLElement).closest("button")) return;
    copyToClipboard();
  };

  return (
    <div
      onMouseDown={handleRowActivate}
      className={`bg-[oklch(0.985_0_0)] relative rounded-xl border flex transition-colors cursor-pointer hover:bg-neutral-100/80 ${
        isSelected ? "border-neutral-400" : "border-neutral-200"
      } ${isImg ? "p-3 flex-col gap-2" : "px-4 py-3 gap-2 justify-between items-center"}`}
    >
      {/* ── Image with thumbnail ── */}
      {isImg && (
        <>
          <div className="rounded-lg overflow-hidden bg-neutral-100 border border-neutral-200 w-full">
            <img
              alt="Clipboard image"
              className="w-full object-contain"
              src={item.value}
              style={{ maxHeight: 140 }}
            />
          </div>
          <div className="flex absolute right-2 top-2 flex-col items-end gap-1">
            <ItemMenu onArchive={onArchive} onDelete={onDelete} />
            <button onClick={(e) => { e.stopPropagation(); onPin(); }} className="rounded-md p-1 mt-4 hover:bg-neutral-200/60 transition-colors">
              {item.pinned ? <PinOff className="size-4 text-neutral-950" /> : <Pin className="size-4 text-neutral-400" />}
            </button>
          </div>
          <div className="flex items-center gap-1.5">
            <Image className="size-3 text-neutral-400" />
            <span className="text-[10px] text-neutral-400 truncate">{item.filename ?? "Image"} · click to copy</span>
          </div>
        </>
      )}

      {/* ── Image filename (from Finder) — no thumbnail available ── */}
      {isFile && (
        <>
          <div className="flex items-center gap-3 flex-1 min-w-0">
            <div className="flex-shrink-0 rounded-lg bg-sky-50 border border-sky-100 flex items-center justify-center w-10 h-10">
              <Image className="size-5 text-sky-400" />
            </div>
            <div className="flex-1 min-w-0">
              <p className="text-xs font-medium text-neutral-950 truncate">{item.filename ?? item.value}</p>
              <p className="text-[10px] text-neutral-400 mt-0.5">Image file · paste (⌘V) for thumbnail</p>
            </div>
          </div>
          <div className="flex flex-col items-end gap-1 flex-shrink-0">
            <ItemMenu onArchive={onArchive} onDelete={onDelete} />
            <button onClick={(e) => { e.stopPropagation(); onPin(); }} className="rounded-md p-1 hover:bg-neutral-200/60 transition-colors">
              {item.pinned ? <PinOff className="size-4 text-neutral-950" /> : <Pin className="size-4 text-neutral-400" />}
            </button>
          </div>
        </>
      )}

      {/* ── Plain text ── */}
      {!isImg && !isFile && (
        <>
          <div className="flex flex-col flex-1 min-w-0 pr-2">
            <span className="font-medium text-neutral-950 text-xs leading-4 truncate">
              {item.value}
            </span>
            <ExpiryBadge item={item} />
          </div>
          <div className="flex flex-col items-end gap-1 flex-shrink-0">
            <ItemMenu onArchive={onArchive} onDelete={onDelete} />
            <button onClick={(e) => { e.stopPropagation(); onPin(); }} className="rounded-md p-1 hover:bg-neutral-200/60 transition-colors">
              {item.pinned ? <PinOff className="size-4 text-neutral-950" /> : <Pin className="size-4 text-neutral-400" />}
            </button>
          </div>
        </>
      )}
    </div>
  );
}

/* ─── Expiry badge ─── */
function ExpiryBadge({ item }: { item: ClipItem }) {
  if (item.pinned) return null;
  const ms = item.expiresAt - Date.now();
  if (ms <= 0) return null;

  let label = "";
  if (ms < HOUR_MS) {
    const mins = Math.ceil(ms / 60_000);
    label = `expires in ${mins}m`;
  } else if (ms < DAY_MS) {
    const hrs = Math.ceil(ms / HOUR_MS);
    label = `expires in ${hrs}h`;
  } else {
    label = "expires in 24h";
  }

  return <span className="text-[9px] text-neutral-300 mt-0.5">{label}</span>;
}

/* ─── Empty state ─── */
function EmptyClipboard() {
  return (
    <div className="flex flex-col items-center justify-center py-12 gap-3 text-center px-6">
      <div className="rounded-2xl bg-neutral-100 p-4">
        <ClipboardList className="size-8 text-neutral-400" />
      </div>
      <p className="font-semibold text-neutral-950 text-sm">No items yet</p>
      <p className="text-neutral-400 text-xs leading-5">
        Copy anything on your device and it will appear here automatically.
      </p>
    </div>
  );
}

/* ─── Main App ─── */
export default function App() {
  const inElectron = isElectron();
  const [navTab, setNavTab] = useState<NavTab>("clipboard");
  const [categoryTab, setCategoryTab] = useState<CategoryTab>("clipboard");
  const [items, setItems] = useState<ClipItem[]>(loadItems);
  const [snippets, setSnippets] = useState<Snippet[]>(loadSnippets);
  const [showAddSnippet, setShowAddSnippet] = useState(false);
  const [historyOn, setHistoryOn] = useState<boolean>(loadHistoryOn);
  const [visible, setVisible] = useState(!inElectron);
  const [popupPos, setPopupPos] = useState<{ x: number; y: number }>({ x: 100, y: 100 });
  const [shortcut, setShortcut] = useState<ShortcutConfig>(loadShortcut);
  const lastClip    = useRef<string>("");
  const mousePos    = useRef<{ x: number; y: number }>({ x: window.innerWidth / 2, y: window.innerHeight / 2 });
  const lastFocused = useRef<HTMLElement | null>(null);
  const popupRef    = useRef<HTMLDivElement>(null);

  const hidePopup = useCallback(() => {
    setVisible(false);
    if (inElectron) void window.electronAPI?.hidePopup();
  }, [inElectron]);

  /* ── Track mouse position globally ── */
  useEffect(() => {
    const handler = (e: MouseEvent) => { mousePos.current = { x: e.clientX, y: e.clientY }; };
    window.addEventListener("mousemove", handler, { passive: true });
    return () => window.removeEventListener("mousemove", handler);
  }, []);

  /* ── Track last focused element (excluding popup itself) ── */
  useEffect(() => {
    const handler = (e: FocusEvent) => {
      const el = e.target as HTMLElement;
      if (popupRef.current?.contains(el)) return;
      if (
        el instanceof HTMLInputElement ||
        el instanceof HTMLTextAreaElement ||
        el.isContentEditable
      ) {
        lastFocused.current = el;
      }
    };
    document.addEventListener("focusin", handler, true);
    return () => document.removeEventListener("focusin", handler, true);
  }, []);

  /* ── Compute popup position keeping it in viewport ── */
  const openPopupAtCursor = useCallback(() => {
    const POPUP_W = 400;
    const POPUP_H = 560;
    const PAD     = 10;
    const { x, y } = mousePos.current;
    const vw = window.innerWidth;
    const vh = window.innerHeight;

    let left = x - POPUP_W / 2;
    let top  = y - POPUP_H - 12; /* appear above cursor */

    if (left + POPUP_W > vw - PAD) left = vw - POPUP_W - PAD;
    if (left < PAD) left = PAD;
    if (top < PAD) top = y + 20; /* flip below if too high */
    if (top + POPUP_H > vh - PAD) top = vh - POPUP_H - PAD;

    setPopupPos({ x: left, y: top });
    setVisible(true);
  }, []);

  /* ── Global shortcut listener (browser only) ── */
  useEffect(() => {
    if (inElectron) return;
    const handler = (e: KeyboardEvent) => {
      if (matchesShortcut(e, shortcut)) {
        e.preventDefault();
        if (visible) hidePopup();
        else openPopupAtCursor();
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [inElectron, shortcut, visible, openPopupAtCursor, hidePopup]);

  /* ── Close popup when clicking outside (browser only) ── */
  useEffect(() => {
    if (inElectron || !visible) return;
    const handler = (e: MouseEvent) => {
      if (popupRef.current && !popupRef.current.contains(e.target as Node)) {
        hidePopup();
      }
    };
    document.addEventListener("mousedown", handler);
    return () => document.removeEventListener("mousedown", handler);
  }, [inElectron, visible, hidePopup]);

  /* ── Auto-paste into last focused element / system editor ── */
  const pasteToFocused = useCallback((text: string) => {
    if (inElectron && window.electronAPI) {
      void window.electronAPI.pasteText(text);
      return;
    }
    hidePopup();
    const el = lastFocused.current;
    if (!el) return;
    requestAnimationFrame(() => {
      el.focus();
      if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) {
        const start = el.selectionStart ?? el.value.length;
        const end   = el.selectionEnd   ?? el.value.length;
        el.setRangeText(text, start, end, "end");
        el.dispatchEvent(new Event("input", { bubbles: true }));
      } else if (el.isContentEditable) {
        document.execCommand("insertText", false, text);
      }
    });
  }, [inElectron, hidePopup]);

  const pasteItemToSystem = useCallback((item: ClipItem) => {
    if (!inElectron || !window.electronAPI) return;
    if (item.type === "text" || item.type === "file") {
      void window.electronAPI.pasteText(item.value);
    } else if (item.type === "image") {
      void window.electronAPI.pasteImage(item.value);
    }
  }, [inElectron]);

  /* Persist snippets */
  useEffect(() => { saveSnippets(snippets); }, [snippets]);

  /* Persist clipboard items */
  useEffect(() => { saveItems(items); }, [items]);

  /* Persist history setting */
  useEffect(() => {
    localStorage.setItem(HISTORY_KEY, String(historyOn));
  }, [historyOn]);

  /* ── Auto-cleanup expired items every 60s ── */
  useEffect(() => {
    const cleanup = () => {
      const now = Date.now();
      setItems((prev) => prev.filter((i) => i.pinned || i.expiresAt > now));
    };
    cleanup();
    const t = setInterval(cleanup, 60_000);
    return () => clearInterval(t);
  }, []);

  /* ── When history is toggled OFF: shorten unpinned items' expiry to 1h ── */
  useEffect(() => {
    const now = Date.now();
    if (!historyOn) {
      setItems((prev) => prev.map((i) =>
        i.pinned ? i : { ...i, expiresAt: Math.min(i.expiresAt, now + HOUR_MS) }
      ));
    } else {
      /* History turned ON: extend unpinned items back to 24h from original timestamp */
      setItems((prev) => prev.map((i) =>
        i.pinned ? i : { ...i, expiresAt: i.timestamp + DAY_MS }
      ));
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [historyOn]);

  const addSnippet = (label: string, value: string) => {
    if (!value.trim()) return;
    const s: Snippet = { id: crypto.randomUUID(), label: label.trim() || "Untitled", value, createdAt: Date.now() };
    setSnippets((prev) => [s, ...prev]);
  };

  const deleteSnippet = (id: string) =>
    setSnippets((prev) => prev.filter((s) => s.id !== id));

  /* Convert image blob → compact JPEG thumbnail (max 400px) */
  const blobToThumb = (blob: Blob): Promise<string> =>
    new Promise((resolve, reject) => {
      const url = URL.createObjectURL(blob);
      const img = new window.Image();
      img.onload = () => {
        const MAX = 400;
        const scale = Math.min(1, MAX / Math.max(img.width, img.height));
        const canvas = document.createElement("canvas");
        canvas.width  = img.width  * scale;
        canvas.height = img.height * scale;
        canvas.getContext("2d")!.drawImage(img, 0, 0, canvas.width, canvas.height);
        URL.revokeObjectURL(url);
        resolve(canvas.toDataURL("image/jpeg", 0.82));
      };
      img.onerror = reject;
      img.src = url;
    });

  /* Add image blob as thumbnail item */
  const addImageItem = useCallback(async (blob: Blob, filename?: string) => {
    try {
      const dataUrl = await blobToThumb(blob);
      const now = Date.now();
      setItems((prev) => {
        const lastImg = prev.find((i) => i.type === "image");
        if (lastImg && lastImg.value === dataUrl) return prev;
        return [{
          id: crypto.randomUUID(),
          type: "image" as const,
          value: dataUrl,
          filename,
          pinned: false,
          archived: false,
          timestamp: now,
          expiresAt: now + (historyOn ? DAY_MS : HOUR_MS),
        }, ...prev];
      });
    } catch { /* ignore */ }
  }, [historyOn]);

  /* Add plain text item */
  const addTextItem = useCallback((text: string) => {
    if (!text.trim() || text === lastClip.current) return;
    lastClip.current = text;
    const isImgFile = IMAGE_EXTS.test(text.trim());
    const now = Date.now();
    setItems((prev) => {
      if (prev.some((i) => i.value === text)) return prev;
      return [{
        id: crypto.randomUUID(),
        type: isImgFile ? ("file" as const) : ("text" as const),
        value: text,
        filename: isImgFile ? text.trim() : undefined,
        pinned: false,
        archived: false,
        timestamp: now,
        expiresAt: now + (historyOn ? DAY_MS : HOUR_MS),
      }, ...prev];
    });
  }, [historyOn]);

  const addImageFromDataUrl = useCallback(async (dataUrl: string, filename?: string) => {
    try {
      const res = await fetch(dataUrl);
      const blob = await res.blob();
      await addImageItem(blob, filename);
    } catch { /* ignore */ }
  }, [addImageItem]);

  /* ── Electron: global shortcut, clipboard sync, popup events ── */
  useEffect(() => {
    if (!inElectron || !window.electronAPI) return;
    const api = window.electronAPI;

    void api.registerShortcut(shortcut);

    const offShown  = api.onPopupShown(() => setVisible(true));
    const offHidden = api.onPopupHidden(() => setVisible(false));
    const offText   = api.onClipboardText(({ text }) => addTextItem(text));
    const offImage  = api.onClipboardImage(({ dataUrl, filename }) => {
      void addImageFromDataUrl(dataUrl, filename);
    });

    return () => {
      offShown();
      offHidden();
      offText();
      offImage();
    };
  }, [inElectron, shortcut, addTextItem, addImageFromDataUrl]);

  /* Poll clipboard on window focus & periodically */
  const readClipboard = useCallback(async () => {
    try {
      const clipItems = await navigator.clipboard.read();
      for (const clipItem of clipItems) {
        /* ── Image blob ── */
        const imgType = clipItem.types.find((t) => t.startsWith("image/"));
        if (imgType) {
          const blob = await clipItem.getType(imgType);
          const key = `${blob.size}-${blob.type}`;
          if (key === lastClip.current) continue;
          lastClip.current = key;
          await addImageItem(blob);
          continue;
        }
        /* ── Text / filename ── */
        if (clipItem.types.includes("text/plain")) {
          const text = await (await clipItem.getType("text/plain")).text();
          addTextItem(text);
        }
      }
    } catch {
      /* Fallback: readText only */
      try {
        const text = await navigator.clipboard.readText();
        addTextItem(text);
      } catch { /* permission denied */ }
    }
  }, [addImageItem, addTextItem]);

  /* ── Paste event — captures image files directly ── */
  useEffect(() => {
    const onPaste = async (e: ClipboardEvent) => {
      const items = e.clipboardData?.items ?? [];
      for (const item of Array.from(items)) {
        if (item.kind === "file" && item.type.startsWith("image/")) {
          const file = item.getAsFile();
          if (file) await addImageItem(file, file.name);
        }
      }
    };
    document.addEventListener("paste", onPaste);
    return () => document.removeEventListener("paste", onPaste);
  }, [addImageItem]);

  useEffect(() => {
    if (inElectron) return;
    let lastRead = 0;

    /* Throttled read — at most once per 400ms */
    const throttledRead = () => {
      const now = Date.now();
      if (now - lastRead < 400) return;
      lastRead = now;
      void readClipboard();
    };

    /* 1. Window gains focus (user switches from another app) */
    const onFocus = () => { lastRead = 0; throttledRead(); };

    /* 2. Tab becomes visible */
    const onVisible = () => { if (!document.hidden) { lastRead = 0; throttledRead(); } };

    /* 3. Any copy event on the page */
    const onCopy = () => setTimeout(() => { lastRead = 0; void readClipboard(); }, 80);

    /* 4. Mouse moves into the app — feels instant to the user */
    const onPointer = () => throttledRead();

    /* 5. Keyboard shortcut Ctrl/Cmd+C */
    const onKey = (e: KeyboardEvent) => {
      if ((e.ctrlKey || e.metaKey) && e.key === "c") {
        setTimeout(() => { lastRead = 0; void readClipboard(); }, 80);
      }
    };

    /* 6. Fallback polling every 800ms */
    const interval = setInterval(throttledRead, 800);

    window.addEventListener("focus", onFocus);
    document.addEventListener("visibilitychange", onVisible);
    document.addEventListener("copy", onCopy);
    document.addEventListener("pointermove", onPointer, { passive: true });
    document.addEventListener("pointerdown", onPointer, { passive: true });
    document.addEventListener("keydown", onKey);

    return () => {
      clearInterval(interval);
      window.removeEventListener("focus", onFocus);
      document.removeEventListener("visibilitychange", onVisible);
      document.removeEventListener("copy", onCopy);
      document.removeEventListener("pointermove", onPointer);
      document.removeEventListener("pointerdown", onPointer);
      document.removeEventListener("keydown", onKey);
    };
  }, [inElectron, readClipboard]);

  const togglePin = (id: string) =>
    setItems((prev) => prev.map((i) => {
      if (i.id !== id) return i;
      const nowPinned = !i.pinned;
      return {
        ...i,
        pinned: nowPinned,
        /* Pin → never expire.  Unpin → restart 24h (or 1h) timer from now */
        expiresAt: nowPinned ? Infinity : Date.now() + (historyOn ? DAY_MS : HOUR_MS),
      };
    }));

  const archiveItem = (id: string) =>
    setItems((prev) => prev.map((i) => (i.id === id ? { ...i, archived: true } : i)));

  const deleteItem = (id: string) =>
    setItems((prev) => prev.filter((i) => i.id !== id));

  const clearAll = () => setItems([]);

  const visibleItems = items.filter((i) => !i.archived);
  const pinnedItems = visibleItems.filter((i) => i.pinned);
  const unpinnedItems = visibleItems.filter((i) => !i.pinned);
  const sortedItems = [...pinnedItems, ...unpinnedItems];

  const categoryTabs: { id: CategoryTab; icon: React.ReactNode; label: string }[] = [
    { id: "favorites", icon: <Heart className="size-5" />, label: "Favorites" },
    { id: "emoji", icon: <Smile className="size-5" />, label: "Emoji" },
    { id: "gifs", icon: <Image className="size-5" />, label: "GIFs" },
    { id: "text", icon: <Type className="size-5" />, label: "Text" },
    { id: "snippets", icon: <Hash className="size-5" />, label: "Snippets" },
    { id: "clipboard", icon: <ClipboardList className="size-5" />, label: "Clipboard" },
  ];

  /* ── Browser-only pill trigger ── */
  const pill = !inElectron ? (
    <button
      onClick={openPopupAtCursor}
      title={`Show clipboard (${shortcutLabel(shortcut)})`}
      className="fixed bottom-4 right-4 z-[9999] flex items-center gap-2 px-3 py-2 rounded-full bg-neutral-950 text-white text-xs font-medium shadow-lg hover:bg-neutral-700 transition-colors select-none"
    >
      <Copy className="size-3.5" />
      <span>{shortcutLabel(shortcut)}</span>
    </button>
  ) : null;

  const showPopup = inElectron || visible;

  return (
    <>
      {pill}

      {/* ── Floating popup ── */}
      {showPopup && (
        <div
          ref={popupRef}
          style={inElectron ? undefined : { left: popupPos.x, top: popupPos.y, width: 400 }}
          className={
            inElectron
              ? "w-full h-screen text-neutral-950 rounded-2xl border border-neutral-200/80 bg-white overflow-hidden flex flex-col"
              : "fixed z-[9998] text-neutral-950 shadow-[0_16px_64px_0_oklch(0.145_0_0/0.22)] rounded-2xl border border-neutral-200 bg-white overflow-hidden flex flex-col"
          }
        >
          <div className="flex flex-col" style={{ maxHeight: inElectron ? "100vh" : "min(560px, calc(100vh - 32px))" }}>

        {/* Top Nav */}
        <div className="bg-neutral-100/60 border-b border-neutral-200 flex px-3 py-1.5 items-center gap-1 flex-shrink-0">
          {(["clipboard", "emoji", "more", "settings"] as NavTab[]).map((tab) => {
            const icons: Record<NavTab, React.ReactNode> = {
              clipboard: <Copy className="size-5" />,
              emoji: <Smile className="size-5" />,
              more: <Grid3x3 className="size-5" />,
              settings: <Settings className="size-5" />,
            };
            const labels: Record<NavTab, string> = {
              clipboard: "Clipboard", emoji: "Emoji", more: "More", settings: "Settings",
            };
            return (
              <Button
                key={tab}
                onClick={() => setNavTab(tab)}
                className={`font-normal rounded-lg text-xs leading-4 flex px-3 py-2 flex-col items-center gap-1 h-auto transition-colors ${
                  navTab === tab ? "text-neutral-950 bg-neutral-100" : "text-neutral-500"
                }`}
                variant="ghost"
              >
                {icons[tab]}
                <span>{labels[tab]}</span>
              </Button>
            );
          })}
        </div>

        {/* Content */}
        <div className="flex flex-col flex-1 overflow-hidden">

          {/* ── Clipboard Nav Tab ── */}
          {navTab === "clipboard" && (
            <div className="flex flex-col flex-1 overflow-hidden">

              {/* ── Fixed header: X + category tabs — never moves ── */}
              <div className="bg-white flex-shrink-0">
                {/* X button */}
                <div className="flex px-4 pt-2 pb-0 justify-end">
                  <button
                    onClick={hidePopup}
                    className="rounded-full flex p-1 justify-center items-center hover:bg-neutral-100 transition-colors"
                  >
                    <X className="size-4 text-neutral-500" />
                  </button>
                </div>

                {/* Category Tabs — center aligned */}
                <div className="border-b border-neutral-200 flex justify-center px-4 pb-2 items-center gap-1">
                  {categoryTabs.map((tab) => (
                    <button
                      key={tab.id}
                      onClick={() => setCategoryTab(tab.id)}
                      title={tab.label}
                      className={`relative rounded-lg flex p-2 justify-center items-center transition-colors ${
                        categoryTab === tab.id
                          ? "bg-neutral-100 text-neutral-950"
                          : "text-neutral-500 hover:bg-neutral-50"
                      }`}
                    >
                      {tab.icon}
                      {categoryTab === tab.id && (
                        <span className="left-1/2 -translate-x-1/2 rounded-full bg-neutral-950 absolute bottom-0.5 w-4 h-0.5" />
                      )}
                    </button>
                  ))}
                </div>
              </div>

              {/* ── Dynamic content — scrollable ── */}
              <div className="overflow-y-auto flex-1">

              {/* ── Favorites ── */}
              {categoryTab === "favorites" && (
                <div className="flex px-4 pt-4 pb-4 flex-col gap-3">
                  <span className="font-semibold text-neutral-950 text-sm leading-5 mb-1">Favorites</span>
                  {pinnedItems.length === 0 ? (
                    <div className="flex flex-col items-center justify-center py-10 gap-3 text-center">
                      <div className="rounded-2xl bg-neutral-100 p-4">
                        <Heart className="size-7 text-neutral-400" />
                      </div>
                      <p className="text-neutral-400 text-xs leading-5">
                        Pin items from Clipboard to see them here.
                      </p>
                    </div>
                  ) : (
                    pinnedItems.map((item, i) => (
                      <ClipRow
                        key={item.id}
                        item={item}
                        isSelected={i === 0}
                        onPin={() => togglePin(item.id)}
                        onArchive={() => archiveItem(item.id)}
                        onDelete={() => deleteItem(item.id)}
                        onSelect={item.type === "text" ? pasteToFocused : undefined}
                        onPaste={inElectron ? pasteItemToSystem : undefined}
                      />
                    ))
                  )}
                </div>
              )}

              {/* ── Emoji ── */}
              {categoryTab === "emoji" && (
                <div className="pt-3 pb-1">
                  <p className="text-[10px] font-semibold text-neutral-400 uppercase tracking-wide px-4 pb-2">
                    All Emojis · click to copy
                  </p>
                  <EmojiPicker onSelect={inElectron ? pasteToFocused : undefined} />
                </div>
              )}

              {/* ── GIFs ── */}
              {categoryTab === "gifs" && (
                <div className="pt-3 pb-1">
                  <p className="text-[10px] font-semibold text-neutral-400 uppercase tracking-wide px-4 pb-2">
                    GIFs · click to copy URL
                  </p>
                  <GifPicker onSelect={inElectron ? pasteToFocused : undefined} />
                </div>
              )}

              {/* ── Text Snippets ── */}
              {categoryTab === "text" && (
                <div className="flex px-4 pt-4 pb-4 flex-col gap-3">
                  <div className="flex mb-1 justify-between items-center">
                    <span className="font-semibold text-neutral-950 text-sm">Text Snippets</span>
                    <Button
                      onClick={() => setShowAddSnippet((v) => !v)}
                      className="rounded-lg bg-white text-neutral-950 text-xs border-neutral-200 border px-3 h-7 gap-1"
                      variant="outline"
                    >
                      <NotebookPen className="size-3" />
                      {showAddSnippet ? "Cancel" : "+ Add"}
                    </Button>
                  </div>

                  {/* Notepad-style add form */}
                  {showAddSnippet && (
                    <SnippetForm
                      onSave={(label, value) => {
                        addSnippet(label, value);
                        setShowAddSnippet(false);
                      }}
                      onCancel={() => setShowAddSnippet(false)}
                    />
                  )}

                  {/* Snippet list */}
                  {snippets.length === 0 && !showAddSnippet && (
                    <div className="flex flex-col items-center justify-center py-8 gap-2 text-center">
                      <div className="rounded-2xl bg-neutral-100 p-4">
                        <NotebookPen className="size-7 text-neutral-400" />
                      </div>
                      <p className="font-semibold text-neutral-950 text-sm">No snippets yet</p>
                      <p className="text-neutral-400 text-xs leading-5">
                        Click "+ Add" to save a reusable text snippet.
                      </p>
                    </div>
                  )}

                  {snippets.map((s) => (
                    <SnippetCard
                      key={s.id}
                      snippet={s}
                      onDelete={() => deleteSnippet(s.id)}
                    />
                  ))}
                </div>
              )}

              {/* ── Special Characters ── */}
              {categoryTab === "snippets" && (
                <div className="pt-3 pb-1">
                  <p className="text-[10px] font-semibold text-neutral-400 uppercase tracking-wide px-4 pb-2">
                    Special Characters · click to copy
                  </p>
                  <SpecialCharPicker onSelect={inElectron ? pasteToFocused : undefined} />
                </div>
              )}

              {/* ── Clipboard History ── */}
              {categoryTab === "clipboard" && (
                <div className="flex px-4 pt-4 pb-2 flex-col gap-3">
                  <div className="flex mb-1 justify-between items-center">
                    <span className="font-semibold text-neutral-950 text-sm leading-5">Clipboard</span>
                    {sortedItems.length > 0 && (
                      <Button
                        onClick={clearAll}
                        className="rounded-lg bg-white text-neutral-950 text-xs border-neutral-200 border px-3 h-7"
                        variant="outline"
                      >
                        Clear all
                      </Button>
                    )}
                  </div>

                  {sortedItems.length === 0 ? (
                    <EmptyClipboard />
                  ) : (
                    sortedItems.map((item, i) => (
                      <ClipRow
                        key={item.id}
                        item={item}
                        isSelected={i === 0}
                        onPin={() => togglePin(item.id)}
                        onArchive={() => archiveItem(item.id)}
                        onDelete={() => deleteItem(item.id)}
                        onSelect={item.type === "text" ? pasteToFocused : undefined}
                        onPaste={inElectron ? pasteItemToSystem : undefined}
                      />
                    ))
                  )}
                </div>
              )}

              </div>

              {/* ── Footer ── */}
              <div className="bg-neutral-100/40 border-t border-neutral-200 flex px-4 py-3 justify-between items-center rounded-b-2xl">
                <div className="flex items-center gap-2">
                  <Info className={`size-4 ${historyOn ? "text-neutral-500" : "text-amber-500"}`} />
                  <span className="text-neutral-500 text-xs leading-4">
                    Clipboard history is{" "}
                    <span className={historyOn ? "text-neutral-950 font-medium" : "text-amber-500 font-medium"}>
                      {historyOn ? "on" : "off"}
                    </span>
                  </span>
                </div>
                <button
                  onClick={() => setHistoryOn((v) => !v)}
                  className="underline underline-offset-2 text-neutral-950 text-xs leading-4 hover:text-neutral-500 transition-colors"
                >
                  {historyOn ? "Turn off" : "Turn on"}
                </button>
              </div>
            </div>
          )}

          {/* ── Emoji Nav Tab ── */}
          {navTab === "emoji" && (
            <div className="flex flex-col flex-1 overflow-hidden">
              <div className="flex px-4 pt-3 pb-2 justify-between items-center flex-shrink-0">
                <span className="font-semibold text-neutral-950 text-sm">Emoji</span>
              </div>
              <div className="overflow-y-auto flex-1">
                <EmojiPicker />
                <div className="h-3" />
              </div>
            </div>
          )}

          {/* ── More Nav Tab ── */}
          {navTab === "more" && (
            <div className="flex flex-col flex-1 overflow-hidden">
              <div className="flex px-4 pt-3 pb-2 justify-between items-center flex-shrink-0">
                <span className="font-semibold text-neutral-950 text-sm">More</span>
              </div>
              <div className="px-4 pb-4 flex flex-col gap-2 overflow-y-auto">
                {[
                  { icon: <ClipboardList className="size-4" />, label: "Clipboard History", count: sortedItems.length },
                  { icon: <Heart className="size-4" />, label: "Favorites", count: pinnedItems.length },
                  { icon: <Archive className="size-4" />, label: "Archive", count: items.filter((i) => i.archived).length },
                  { icon: <Hash className="size-4" />, label: "Snippets", count: snippets.length },
                ].map(({ icon, label, count }) => (
                  <button key={label} className="flex items-center justify-between px-4 py-3 rounded-xl bg-[oklch(0.985_0_0)] border border-neutral-200 text-sm font-medium text-neutral-950 hover:bg-neutral-100 transition-colors">
                    <span className="flex items-center gap-3">
                      <span className="text-neutral-500">{icon}</span>
                      {label}
                    </span>
                    {count > 0 && (
                      <span className="text-xs text-neutral-400 bg-neutral-100 rounded-full px-2 py-0.5">{count}</span>
                    )}
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* ── Settings Nav Tab ── */}
          {navTab === "settings" && (
            <div className="flex flex-col flex-1 overflow-hidden">
              <div className="flex px-4 pt-3 pb-2 justify-between items-center">
                <span className="font-semibold text-neutral-950 text-sm">Settings</span>
                <button onClick={() => setNavTab("clipboard")} className="rounded-full flex p-1 hover:bg-neutral-100 transition-colors">
                  <X className="size-4 text-neutral-500" />
                </button>
              </div>
              <div className="overflow-y-auto flex-1">
                <SettingsPanel
                  historyOn={historyOn}
                  onHistoryToggle={() => setHistoryOn((v) => !v)}
                  shortcut={shortcut}
                  onShortcutSave={(s) => {
                    setShortcut(s);
                    localStorage.setItem(SHORTCUT_KEY, JSON.stringify(s));
                    if (inElectron) void window.electronAPI?.registerShortcut(s);
                  }}
                />
              </div>
            </div>
          )}

          </div>
          </div>
        </div>
      )}
    </>
  );
}

function SettingsPanel({
  historyOn, onHistoryToggle, shortcut, onShortcutSave,
}: {
  historyOn: boolean;
  onHistoryToggle: () => void;
  shortcut: ShortcutConfig;
  onShortcutSave: (s: ShortcutConfig) => void;
}) {
  const [toggles, setToggles] = useState({ login: false, menubar: true, sound: false });
  const toggle = (key: keyof typeof toggles) =>
    setToggles((prev) => ({ ...prev, [key]: !prev[key] }));

  const settings: { key: string; label: string; desc: string; value: boolean; onToggle: () => void }[] = [
    {
      key: "history",
      label: "Clipboard History",
      desc: historyOn ? "Items saved 24h · pinned forever" : "Items saved 1h · session only",
      value: historyOn,
      onToggle: onHistoryToggle,
    },
    { key: "login",   label: "Launch at Login",  desc: "Start ClipBoard Pro on startup",  value: toggles.login,   onToggle: () => toggle("login") },
    { key: "menubar", label: "Show in Menu Bar", desc: "Keep icon in the menu bar",         value: toggles.menubar, onToggle: () => toggle("menubar") },
    { key: "sound",   label: "Sound Effects",    desc: "Play sounds on copy",               value: toggles.sound,   onToggle: () => toggle("sound") },
  ];

  return (
    <>
      <div className="px-4 pb-4 flex flex-col gap-3">
        {settings.map(({ key, label, desc, value, onToggle }) => (
          <button
            key={key}
            onClick={onToggle}
            className="flex items-center justify-between px-4 py-3 rounded-xl bg-[oklch(0.985_0_0)] border border-neutral-200 text-left w-full hover:bg-neutral-50 transition-colors"
          >
            <div>
              <p className="text-sm font-medium text-neutral-950">{label}</p>
              <p className="text-xs text-neutral-500 mt-0.5">{desc}</p>
            </div>
            <div className={`w-9 h-5 rounded-full relative transition-colors flex-shrink-0 ${value ? "bg-neutral-950" : "bg-neutral-200"}`}>
              <span className={`absolute top-0.5 w-4 h-4 bg-white rounded-full shadow transition-transform ${value ? "translate-x-4" : "translate-x-0.5"}`} />
            </div>
          </button>
        ))}

        {/* Shortcut Editor */}
        <ShortcutEditor current={shortcut} onSave={onShortcutSave} />
      </div>
      <div className="bg-neutral-100/40 border-t border-neutral-200 flex px-4 py-3 justify-between items-center">
        <span className="text-neutral-500 text-xs">ClipBoard Pro v1.2.0</span>
        <button className="underline underline-offset-2 text-neutral-950 text-xs">Check for updates</button>
      </div>
    </>
  );
}

/* ─── Shortcut Editor ─── */
function ShortcutEditor({ current, onSave }: { current: ShortcutConfig; onSave: (s: ShortcutConfig) => void }) {
  const [draft, setDraft] = useState<ShortcutConfig>(current);
  const [recording, setRecording] = useState(false);
  const [saved, setSaved] = useState(false);
  const inputRef = useRef<HTMLButtonElement>(null);

  /* Sync when parent changes (e.g. on mount) */
  useEffect(() => { setDraft(current); }, [current]);

  /* Capture keydown while recording */
  useEffect(() => {
    if (!recording) return;
    const handler = (e: KeyboardEvent) => {
      e.preventDefault();
      e.stopPropagation();

      /* ignore lone modifier keys */
      const plain = e.key;
      if (["Control", "Meta", "Alt", "Shift"].includes(plain)) return;

      /* Require at least one modifier */
      if (!e.ctrlKey && !e.metaKey && !e.altKey) return;

      setDraft({
        ctrl:  e.ctrlKey,
        meta:  e.metaKey,
        alt:   e.altKey,
        shift: e.shiftKey,
        key:   plain.toUpperCase(),
      });
      setRecording(false);
    };
    window.addEventListener("keydown", handler, true);
    return () => window.removeEventListener("keydown", handler, true);
  }, [recording]);

  const isDifferent = shortcutLabel(draft) !== shortcutLabel(current);

  const handleSave = () => {
    onSave(draft);
    setSaved(true);
    setTimeout(() => setSaved(false), 1500);
  };

  const handleReset = () => {
    setDraft(DEFAULT_SHORTCUT);
    setRecording(false);
  };

  return (
    <div className="rounded-xl bg-[oklch(0.985_0_0)] border border-neutral-200 px-4 py-3 flex flex-col gap-3">
      <div>
        <p className="text-sm font-medium text-neutral-950">Popup Shortcut</p>
        <p className="text-xs text-neutral-500 mt-0.5">Press shortcut to show / hide the popup</p>
      </div>

      {/* Recorder area */}
      <div className="flex items-center gap-2">
        <button
          ref={inputRef}
          onClick={() => setRecording((r) => !r)}
          className={`flex-1 flex items-center justify-center gap-2 rounded-lg border px-3 py-2 text-sm font-mono font-semibold transition-colors
            ${recording
              ? "border-neutral-950 bg-neutral-950 text-white animate-pulse"
              : "border-neutral-200 bg-white text-neutral-950 hover:border-neutral-400"
            }`}
        >
          {recording ? (
            <span className="text-xs font-sans font-normal text-neutral-300">Press keys…</span>
          ) : (
            <span>{shortcutLabel(draft)}</span>
          )}
        </button>
        <button
          onClick={handleReset}
          title="Reset to default"
          className="rounded-lg border border-neutral-200 bg-white px-2.5 py-2 text-xs text-neutral-500 hover:bg-neutral-50 transition-colors"
        >
          Reset
        </button>
      </div>

      {/* Modifier checkboxes */}
      <div className="flex gap-2 flex-wrap">
        {(["ctrl", "meta", "alt", "shift"] as const).map((mod) => {
          const labels = { ctrl: "⌃ Ctrl", meta: "⌘ Cmd", alt: "⌥ Alt", shift: "⇧ Shift" };
          return (
            <button
              key={mod}
              onClick={() => setDraft((d) => ({ ...d, [mod]: !d[mod] }))}
              className={`px-2 py-0.5 rounded-md border text-xs font-medium transition-colors
                ${draft[mod]
                  ? "bg-neutral-950 text-white border-neutral-950"
                  : "bg-white text-neutral-400 border-neutral-200 hover:border-neutral-400"
                }`}
            >
              {labels[mod]}
            </button>
          );
        })}
      </div>

      {/* Save button */}
      <button
        onClick={handleSave}
        disabled={!isDifferent && !saved}
        className={`w-full rounded-lg py-2 text-xs font-semibold transition-all
          ${saved
            ? "bg-green-500 text-white"
            : isDifferent
              ? "bg-neutral-950 text-white hover:bg-neutral-800"
              : "bg-neutral-100 text-neutral-400 cursor-not-allowed"
          }`}
      >
        {saved ? "✓ Saved!" : "Save Shortcut"}
      </button>
    </div>
  );
}

/* ─── Notepad-style snippet form ─── */
function SnippetForm({ onSave, onCancel }: { onSave: (label: string, value: string) => void; onCancel: () => void }) {
  const [label, setLabel] = useState("");
  const [value, setValue] = useState("");
  const textareaRef = useRef<HTMLTextAreaElement>(null);

  useEffect(() => { textareaRef.current?.focus(); }, []);

  /* auto-grow textarea */
  const handleValueChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    setValue(e.target.value);
    e.target.style.height = "auto";
    e.target.style.height = `${Math.min(e.target.scrollHeight, 200)}px`;
  };

  return (
    <div className="rounded-xl border border-neutral-950 border-2 bg-white flex flex-col overflow-hidden shadow-sm">
      {/* Notepad header bar */}
      <div className="flex items-center gap-2 px-3 pt-3 pb-2 border-b border-neutral-100">
        <NotebookPen className="size-3.5 text-neutral-400 flex-shrink-0" />
        <input
          type="text"
          placeholder="Title (optional)"
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          className="flex-1 text-xs font-medium text-neutral-950 placeholder:text-neutral-400 outline-none bg-transparent"
        />
      </div>

      {/* Notepad body */}
      <div className="px-3 py-2 bg-[oklch(0.985_0_0)]" style={{ backgroundImage: "repeating-linear-gradient(transparent, transparent 23px, #e5e7eb 23px, #e5e7eb 24px)", backgroundPositionY: "8px" }}>
        <textarea
          ref={textareaRef}
          placeholder="Type your note here..."
          value={value}
          onChange={handleValueChange}
          rows={4}
          className="w-full bg-transparent text-sm text-neutral-950 placeholder:text-neutral-400 outline-none resize-none leading-6 font-mono"
          style={{ minHeight: 96 }}
        />
      </div>

      {/* Actions */}
      <div className="flex items-center justify-between px-3 py-2 border-t border-neutral-100 bg-white">
        <span className="text-[10px] text-neutral-400">{value.length} chars</span>
        <div className="flex gap-2">
          <button onClick={onCancel} className="text-xs text-neutral-500 hover:text-neutral-700 transition-colors px-2 py-1">
            Cancel
          </button>
          <button
            onClick={() => onSave(label, value)}
            disabled={!value.trim()}
            className="text-xs font-medium bg-neutral-950 text-white rounded-lg px-3 py-1 disabled:opacity-40 hover:bg-neutral-800 transition-colors"
          >
            Save
          </button>
        </div>
      </div>
    </div>
  );
}

/* ─── Snippet card ─── */
function SnippetCard({ snippet, onDelete }: { snippet: Snippet; onDelete: () => void }) {
  const [copied, setCopied] = useState(false);
  const [confirmDelete, setConfirmDelete] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(snippet.value);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  return (
    <div className="bg-[oklch(0.985_0_0)] rounded-xl border border-neutral-200 flex flex-col overflow-hidden group">
      {/* Card header */}
      <div className="flex items-center justify-between px-4 pt-3 pb-1">
        <p className="text-xs font-semibold text-neutral-500">{snippet.label}</p>
        <div className="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
          <button
            onClick={handleCopy}
            title="Copy"
            className="rounded-md p-1 hover:bg-neutral-200/60 transition-colors"
          >
            <Copy className="size-3.5 text-neutral-500" />
          </button>
          {confirmDelete ? (
            <>
              <button
                onClick={() => setConfirmDelete(false)}
                className="rounded-md px-2 py-0.5 text-[10px] text-neutral-500 hover:bg-neutral-200 transition-colors"
              >
                No
              </button>
              <button
                onClick={onDelete}
                className="rounded-md px-2 py-0.5 text-[10px] bg-red-500 text-white hover:bg-red-600 transition-colors"
              >
                Delete?
              </button>
            </>
          ) : (
            <button
              onClick={() => setConfirmDelete(true)}
              title="Delete"
              className="rounded-md p-1 hover:bg-red-50 transition-colors"
            >
              <Trash2 className="size-3.5 text-neutral-400 hover:text-red-500" />
            </button>
          )}
        </div>
      </div>

      {/* Card body */}
      <button onClick={handleCopy} className="px-4 pb-3 text-left w-full">
        <p className="font-medium text-neutral-950 text-sm whitespace-pre-wrap leading-5 line-clamp-4">
          {snippet.value}
        </p>
        {copied && (
          <p className="text-[10px] text-green-500 mt-1 font-medium">Copied!</p>
        )}
      </button>
    </div>
  );
}

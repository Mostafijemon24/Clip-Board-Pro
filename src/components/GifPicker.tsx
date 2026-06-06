import { useState, useEffect, useCallback, useRef } from "react";
import { Search, X, Check, Loader2 } from "lucide-react";
import { isElectron } from "@/lib/isElectron";

const TENOR_KEY = "LIVDSRZULELA";

interface TenorMediaItem {
  gif:     { url: string; preview: string };
  tinygif: { url: string; preview: string };
}

interface TenorResult {
  id: string;
  content_description: string;
  media: TenorMediaItem[];
}

async function fetchGifs(query: string, pos = ""): Promise<{ results: TenorResult[]; next: string }> {
  const params = new URLSearchParams({ key: TENOR_KEY, limit: "12", media_filter: "minimal", contentfilter: "low" });
  if (pos) params.set("pos", pos);
  if (query) params.set("q", query);
  const path = query ? "search" : "trending";
  const url = isElectron()
    ? `https://api.tenor.com/v1/${path}?${params}`
    : `/api/tenor/${path}?${params}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${res.status} ${res.statusText}`);
  const json = await res.json();
  return { results: json.results ?? [], next: json.next ?? "" };
}

/* ── Single GIF tile ── */
function GifTile({ result, onCopy, onPaste }: { result: TenorResult; onCopy: () => void; onPaste?: (url: string) => void }) {
  const [hovered, setHovered] = useState(false);
  const [copied, setCopied] = useState(false);
  const [imgLoaded, setImgLoaded] = useState(false);
  const m = result.media[0];
  if (!m) return null;

  const staticSrc   = m.gif?.preview  ?? m.tinygif?.preview ?? "";
  const animatedSrc = m.tinygif?.url  ?? m.gif?.url ?? "";
  const fullUrl     = m.gif?.url ?? "";

  const handleCopy = () => {
    if (!fullUrl) return;
    if (onPaste) {
      onPaste(fullUrl);
    } else {
      void navigator.clipboard.writeText(fullUrl);
    }
    onCopy();
    setCopied(true);
    setTimeout(() => setCopied(false), 1400);
  };

  return (
    <button
      onClick={handleCopy}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      className="relative rounded-xl overflow-hidden bg-neutral-100 w-full group"
      style={{ aspectRatio: "1/1" }}
      title={result.content_description || "Click to copy"}
    >
      {!imgLoaded && <div className="absolute inset-0 bg-neutral-100 animate-pulse" />}
      <img
        src={hovered ? animatedSrc : staticSrc}
        alt=""
        onLoad={() => setImgLoaded(true)}
        className="w-full h-full object-cover"
        loading="lazy"
        decoding="async"
      />
      <div className="absolute inset-0 bg-black/0 group-hover:bg-black/10 transition-colors" />
      {copied && (
        <div className="absolute inset-0 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-full p-1.5"><Check className="size-3.5 text-neutral-950" /></div>
        </div>
      )}
    </button>
  );
}

function SkeletonGrid({ count = 12 }: { count?: number }) {
  return (
    <>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} className="rounded-xl bg-neutral-100 animate-pulse" style={{ aspectRatio: "1/1" }} />
      ))}
    </>
  );
}

/* ── Main component ── */
export default function GifPicker({ onSelect }: { onSelect?: (url: string) => void }) {
  const [search, setSearch]         = useState("");
  const [query, setQuery]           = useState("");          // committed search term
  const [gifs, setGifs]             = useState<TenorResult[]>([]);
  const [loading, setLoading]       = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError]           = useState<string | null>(null);
  const [nextPos, setNextPos]       = useState("");
  const [hasMore, setHasMore]       = useState(true);

  const scrollRef = useRef<HTMLDivElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  /* ── Initial load on mount (trending) ── */
  useEffect(() => {
    void loadFirst("");
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  /* ── Debounce search input ── */
  const handleSearchChange = (value: string) => {
    setSearch(value);
    if (debounceRef.current) clearTimeout(debounceRef.current);
    debounceRef.current = setTimeout(() => {
      const q = value.trim();
      setQuery(q);
      void loadFirst(q);
    }, 380);
  };

  const loadFirst = async (q: string) => {
    setLoading(true);
    setError(null);
    setGifs([]);
    setNextPos("");
    setHasMore(true);
    try {
      const { results, next } = await fetchGifs(q);
      setGifs(results);
      setNextPos(next);
      setHasMore(results.length >= 12);
    } catch (e) {
      setError(e instanceof Error ? e.message : "Error");
    } finally {
      setLoading(false);
    }
  };

  const loadMore = useCallback(async () => {
    if (loadingMore || !hasMore || !nextPos) return;
    setLoadingMore(true);
    try {
      const { results, next } = await fetchGifs(query, nextPos);
      setGifs((prev) => [...prev, ...results]);
      setNextPos(next);
      if (results.length < 12) setHasMore(false);
    } catch { /* ignore */ }
    finally { setLoadingMore(false); }
  }, [query, nextPos, loadingMore, hasMore]);

  /* ── Infinite scroll ── */
  useEffect(() => {
    const bottom = bottomRef.current;
    const scroll = scrollRef.current;
    if (!bottom || !scroll) return;
    const obs = new IntersectionObserver(
      ([e]) => { if (e.isIntersecting) void loadMore(); },
      { root: scroll, threshold: 0.1 }
    );
    obs.observe(bottom);
    return () => obs.disconnect();
  }, [loadMore]);

  const clearSearch = () => {
    setSearch("");
    if (debounceRef.current) clearTimeout(debounceRef.current);
    setQuery("");
    void loadFirst("");
  };

  return (
    <div className="flex flex-col">
      {/* Search */}
      <div className="relative px-3 pb-2">
        <Search className="absolute left-5 top-1/2 -translate-y-1/2 size-3.5 text-neutral-400" />
        <input
          type="text"
          placeholder="Search GIFs..."
          value={search}
          onChange={(e) => handleSearchChange(e.target.value)}
          className="w-full bg-neutral-100 rounded-lg text-xs px-8 py-1.5 outline-none placeholder:text-neutral-400 text-neutral-950"
        />
        {search && (
          <button onClick={clearSearch} className="absolute right-5 top-1/2 -translate-y-1/2">
            <X className="size-3 text-neutral-400" />
          </button>
        )}
      </div>

      <p className="text-[10px] font-semibold text-neutral-400 uppercase tracking-wide px-4 pb-2">
        {query ? `"${query}"` : "Trending · hover to animate"}
      </p>

      {/* Grid */}
      <div ref={scrollRef} className="overflow-y-auto px-3 pb-2" style={{ maxHeight: 280 }}>
        {error ? (
          <div className="text-center py-8 flex flex-col items-center gap-2">
            <p className="text-neutral-400 text-xs">Could not load GIFs.</p>
            <code className="text-neutral-300 text-[10px] bg-neutral-50 px-2 py-0.5 rounded">{error}</code>
            <button
              onClick={() => void loadFirst(query)}
              className="text-xs font-medium bg-neutral-950 text-white rounded-lg px-3 py-1.5 hover:bg-neutral-800 transition-colors"
            >
              Retry
            </button>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-3 gap-1.5">
              {loading
                ? <SkeletonGrid count={12} />
                : gifs.map((gif) => (
                    <GifTile
                      key={gif.id}
                      result={gif}
                      onPaste={onSelect}
                      onCopy={() => onSelect?.(gif.media[0]?.gif?.url ?? "")}
                    />
                  ))
              }
              {loadingMore && <SkeletonGrid count={3} />}
            </div>

            {loading && gifs.length === 0 && (
              <div className="flex justify-center py-4">
                <Loader2 className="size-4 text-neutral-300 animate-spin" />
              </div>
            )}

            <div ref={bottomRef} className="h-2" />
            {!loading && !hasMore && gifs.length > 0 && (
              <p className="text-center text-[10px] text-neutral-300 py-1">No more GIFs</p>
            )}
          </>
        )}
      </div>

      <p className="text-center text-[9px] text-neutral-300 pb-1.5">Powered by Tenor</p>
    </div>
  );
}

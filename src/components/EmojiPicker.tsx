import { useState, useMemo } from "react";
import data from "@emoji-mart/data";
import { Search, X } from "lucide-react";

interface EmojiData {
  categories: { id: string; emojis: string[] }[];
  emojis: Record<string, { id: string; name: string; skins: { native: string }[] }>;
}

const emojiData = data as EmojiData;

const CATEGORY_LABELS: Record<string, string> = {
  people: "Smileys & People",
  nature: "Animals & Nature",
  foods: "Food & Drink",
  activity: "Activity",
  places: "Travel & Places",
  objects: "Objects",
  symbols: "Symbols",
  flags: "Flags",
  frequent: "Frequently Used",
};

export default function EmojiPicker({ onSelect }: { onSelect?: (emoji: string) => void }) {
  const [search, setSearch] = useState("");
  const [activeCategory, setActiveCategory] = useState(emojiData.categories[0]?.id ?? "people");

  const searchResults = useMemo(() => {
    if (!search.trim()) return null;
    const q = search.toLowerCase();
    return Object.values(emojiData.emojis)
      .filter((e) => e.name.toLowerCase().includes(q) || e.id.includes(q))
      .slice(0, 60)
      .map((e) => e.skins[0]?.native)
      .filter(Boolean) as string[];
  }, [search]);

  const categoryEmojis = useMemo(() => {
    const cat = emojiData.categories.find((c) => c.id === activeCategory);
    if (!cat) return [];
    return cat.emojis
      .map((id) => emojiData.emojis[id]?.skins[0]?.native)
      .filter(Boolean) as string[];
  }, [activeCategory]);

  const displayed = searchResults ?? categoryEmojis;

  const categoryIcons: Record<string, string> = {
    people: "😀", nature: "🐶", foods: "🍕", activity: "⚽",
    places: "✈️", objects: "💡", symbols: "❤️", flags: "🏳️", frequent: "🕐",
  };

  return (
    <div className="flex flex-col h-full">
      {/* Search */}
      <div className="relative px-3 pb-2">
        <Search className="absolute left-5 top-1/2 -translate-y-1/2 size-3.5 text-neutral-400" />
        <input
          type="text"
          placeholder="Search emoji..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          className="w-full bg-neutral-100 rounded-lg text-xs px-8 py-1.5 outline-none placeholder:text-neutral-400 text-neutral-950"
        />
        {search && (
          <button onClick={() => setSearch("")} className="absolute right-5 top-1/2 -translate-y-1/2">
            <X className="size-3 text-neutral-400" />
          </button>
        )}
      </div>

      {/* Category tabs */}
      {!search && (
        <div className="flex px-3 gap-0.5 overflow-x-auto scrollbar-none pb-1">
          {emojiData.categories.map((cat) => (
            <button
              key={cat.id}
              onClick={() => setActiveCategory(cat.id)}
              title={CATEGORY_LABELS[cat.id] ?? cat.id}
              className={`flex-shrink-0 rounded-lg p-1.5 text-base transition-colors ${
                activeCategory === cat.id ? "bg-neutral-200" : "hover:bg-neutral-100"
              }`}
            >
              {categoryIcons[cat.id] ?? "•"}
            </button>
          ))}
        </div>
      )}

      {/* Category label */}
      {!search && (
        <p className="text-[10px] font-semibold text-neutral-400 uppercase tracking-wide px-4 py-1">
          {CATEGORY_LABELS[activeCategory] ?? activeCategory}
        </p>
      )}

      {/* Emoji grid */}
      <div className="overflow-y-auto px-3 pb-3" style={{ maxHeight: 240 }}>
        {displayed.length === 0 ? (
          <p className="text-center text-neutral-400 text-xs py-8">No results found</p>
        ) : (
          <div className="grid grid-cols-8 gap-0.5">
            {displayed.map((emoji, i) => (
              <button
                key={`${emoji}-${i}`}
                onClick={() => {
                  if (onSelect) {
                    onSelect(emoji);
                  } else {
                    void navigator.clipboard.writeText(emoji);
                  }
                }}
                className="rounded-lg p-1.5 text-xl hover:bg-neutral-100 transition-colors leading-none"
                title="Click to copy"
              >
                {emoji}
              </button>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

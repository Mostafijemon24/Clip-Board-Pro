import { useState, useRef, useEffect } from "react";
import { Check, ChevronLeft, ChevronRight } from "lucide-react";


const CHAR_CATEGORIES: { label: string; chars: string[] }[] = [
  {
    label: "Currency",
    chars: ["$","€","£","¥","₹","₩","₪","₫","₺","₿","¢","₴","₦","₱","฿","₲","₡","₢","₣","₤","₥","₧","₨","₭","₮","₯","₰","₵","₸","₼","₽","＄","￡","￥"],
  },
  {
    label: "Math",
    chars: ["±","×","÷","≠","≈","≤","≥","∞","√","∑","∏","∫","∂","∆","∇","∈","∉","⊂","⊃","⊆","⊇","∩","∪","∧","∨","¬","⊕","⊗","⊥","∥","°","′","″"],
  },
  {
    label: "Arrows",
    chars: ["←","→","↑","↓","↔","↕","⇐","⇒","⇑","⇓","⇔","⇕","➡","⬅","⬆","⬇","↗","↖","↘","↙","↺","↻","⟵","⟶","⟷","⟹","↦","↣","↤","↠","⇄","⇆","⇋","⇌"],
  },
  {
    label: "Punctuation",
    chars: [
      "\u2026","\u2014","\u2013","\u00AB","\u00BB",
      "\u2039","\u203A","\u201E","\u201F",
      "\u2018","\u2019","\u0022","\u201C","\u201D",
      "\u2022","\u00B7","\u00B0","\u00B6","\u00A7",
      "\u00A9","\u00AE","\u2122","\u2103","\u2109",
      "\u2116","\u2105","\u2030","\u2031","\u203B",
      "\u2020","\u2021","\u203C","\u2049",
    ],
  },
  {
    label: "Greek",
    chars: ["α","β","γ","δ","ε","ζ","η","θ","ι","κ","λ","μ","ν","ξ","ο","π","ρ","σ","τ","υ","φ","χ","ψ","ω","Α","Β","Γ","Δ","Ε","Ζ","Η","Θ","Ω"],
  },
  {
    label: "Shapes",
    chars: ["■","□","▪","▫","▲","△","▼","▽","◆","◇","●","○","◉","◎","★","☆","♠","♣","♥","♦","⬛","⬜","🔲","🔳","▶","◀","◈","◐","◑","◒","◓","◔","◕"],
  },
  {
    label: "Letters",
    chars: ["Ā","ā","Ă","ă","Ą","ą","Ć","ć","Ĉ","ĉ","Ċ","ċ","Č","č","Ð","ð","É","é","Ê","ê","Ë","ë","Ñ","ñ","Ö","ö","Ü","ü","ß","Æ","æ","Ø","ø"],
  },
  {
    label: "Misc",
    chars: ["♀","♂","⚕","⚡","☀","☁","☂","☃","☄","★","☎","☏","✉","✏","✒","✔","✖","✗","✘","✓","⚐","⚑","⚓","⚔","⚙","⚛","⚜","⚝","⚞","⚟","⚠","⚡","⚣"],
  },
];

const SCROLL_AMOUNT = 120;

export default function SpecialCharPicker({ onSelect }: { onSelect?: (char: string) => void }) {
  const [activeCategory, setActiveCategory] = useState(0);
  const [copied, setCopied] = useState<string | null>(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);
  const tabsRef = useRef<HTMLDivElement>(null);

  const updateScrollState = () => {
    const el = tabsRef.current;
    if (!el) return;
    setCanScrollLeft(el.scrollLeft > 0);
    setCanScrollRight(el.scrollLeft + el.clientWidth < el.scrollWidth - 1);
  };

  useEffect(() => {
    updateScrollState();
    const el = tabsRef.current;
    if (!el) return;
    el.addEventListener("scroll", updateScrollState);
    const ro = new ResizeObserver(updateScrollState);
    ro.observe(el);
    return () => {
      el.removeEventListener("scroll", updateScrollState);
      ro.disconnect();
    };
  }, []);

  /* scroll active tab into view whenever category changes */
  useEffect(() => {
    const el = tabsRef.current;
    if (!el) return;
    const active = el.children[activeCategory] as HTMLElement | undefined;
    active?.scrollIntoView({ behavior: "smooth", block: "nearest", inline: "nearest" });
  }, [activeCategory]);

  const scrollLeft = () => {
    tabsRef.current?.scrollBy({ left: -SCROLL_AMOUNT, behavior: "smooth" });
  };
  const scrollRight = () => {
    tabsRef.current?.scrollBy({ left: SCROLL_AMOUNT, behavior: "smooth" });
  };

  const handleClick = (char: string) => {
    if (onSelect) {
      onSelect(char);
    } else {
      void navigator.clipboard.writeText(char);
    }
    setCopied(char);
    setTimeout(() => setCopied(null), 1200);
  };

  return (
    <div className="flex flex-col">
      {/* Category tabs with scroll arrows */}
      <div className="relative flex items-center px-3 pb-2 gap-1">
        {/* Left arrow */}
        <button
          onClick={scrollLeft}
          disabled={!canScrollLeft}
          className={`flex-shrink-0 rounded-md p-0.5 transition-opacity ${
            canScrollLeft ? "opacity-100 hover:bg-neutral-100" : "opacity-0 pointer-events-none"
          }`}
        >
          <ChevronLeft className="size-4 text-neutral-500" />
        </button>

        {/* Scrollable tab row */}
        <div
          ref={tabsRef}
          className="flex gap-1 overflow-x-auto scrollbar-none flex-1"
          onScroll={updateScrollState}
        >
          {CHAR_CATEGORIES.map((cat, i) => (
            <button
              key={cat.label}
              onClick={() => setActiveCategory(i)}
              className={`flex-shrink-0 rounded-lg px-2.5 py-1 text-xs font-medium transition-colors ${
                activeCategory === i
                  ? "bg-neutral-800 text-neutral-50"
                  : "bg-neutral-100 text-neutral-400 hover:bg-neutral-200 hover:text-neutral-600"
              }`}
            >
              {cat.label}
            </button>
          ))}
        </div>

        {/* Right arrow */}
        <button
          onClick={scrollRight}
          disabled={!canScrollRight}
          className={`flex-shrink-0 rounded-md p-0.5 transition-opacity ${
            canScrollRight ? "opacity-100 hover:bg-neutral-100" : "opacity-0 pointer-events-none"
          }`}
        >
          <ChevronRight className="size-4 text-neutral-500" />
        </button>
      </div>

      <p className="text-[10px] font-semibold text-neutral-400 uppercase tracking-wide px-4 pb-1">
        {CHAR_CATEGORIES[activeCategory].label}
      </p>

      {/* Character grid */}
      <div className="overflow-y-auto px-3 pb-3" style={{ maxHeight: 240 }}>
        <div className="grid grid-cols-8 gap-0.5">
          {CHAR_CATEGORIES[activeCategory].chars.map((char) => (
            <button
              key={char}
              onClick={() => handleClick(char)}
              className="relative rounded-lg p-1 text-sm hover:bg-neutral-100 transition-colors flex items-center justify-center"
              title={`Copy "${char}"`}
              style={{ color: "#333333", fontWeight: 400 }}
            >
              {copied === char ? (
                <Check className="size-3.5 text-green-500" />
              ) : (
                char
              )}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}

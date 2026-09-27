// supabase/functions/scan-expense/matching.ts
// Pure helpers: which supplier issued the document, which learned catalog entry a line is,
// and how many material units one purchased unit contains.

export interface SupplierRow {
  id: string;
  name: string;
  vat_id: string | null;
  aliases: string[] | null;
}

export interface CatalogRow {
  id: string;
  article_number: string | null;
  receipt_name: string | null;
  material_id: string | null;
  conversion_ratio: number | null;
  created_at: string;
}

export interface SupplierMatch {
  status: "matched" | "suggested" | "unknown";
  supplier_id: string | null;
  score: number;
}

const LEGAL_WORDS = new Set([
  "gmbh", "gesmbh", "ges", "mbh", "m.b.h", "kg", "og", "eu", "e.u", "ag", "co", "cokg", "und", "and",
  "handels", "handelsgesellschaft", "ltd", "inc", "sarl", "srl", "bv",
]);

/** "SG Import & Export GmbH" and "S&G Import Export" both become "sgimportexport". */
export function compactCompany(name: string): string {
  return name
    .toLowerCase()
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .split(/[^a-z0-9]+/)
    .filter((w) => w && !LEGAL_WORDS.has(w))
    .join("");
}

export function matchSupplier(
  seen: { name: string | null; vat_id: string | null },
  suppliers: SupplierRow[],
): SupplierMatch {
  const vat = seen.vat_id?.replace(/\s+/g, "").toUpperCase();
  if (vat) {
    const byVat = suppliers.find((s) => s.vat_id && s.vat_id.replace(/\s+/g, "").toUpperCase() === vat);
    if (byVat) return { status: "matched", supplier_id: byVat.id, score: 1 };
  }
  if (!seen.name) return { status: "unknown", supplier_id: null, score: 0 };

  const target = compactCompany(seen.name);
  let best: SupplierMatch = { status: "unknown", supplier_id: null, score: 0 };
  for (const s of suppliers) {
    for (const candidate of [s.name, ...(s.aliases ?? [])]) {
      const c = compactCompany(candidate);
      if (!c || !target) continue;
      let score = 0;
      if (c === target) score = 0.95;
      else if (Math.min(c.length, target.length) >= 4 && (c.includes(target) || target.includes(c))) score = 0.85;
      else score = similarity(c, target) * 0.8;
      if (score > best.score) best = { status: "unknown", supplier_id: s.id, score };
    }
  }
  if (best.score >= 0.85) return { ...best, status: "matched" };
  if (best.score >= 0.5) return { ...best, status: "suggested" };
  return { status: "unknown", supplier_id: null, score: best.score };
}

/** Dice coefficient on character bigrams (0..1). */
export function similarity(a: string, b: string): number {
  if (a === b) return 1;
  if (a.length < 2 || b.length < 2) return 0;
  const grams = new Map<string, number>();
  for (let i = 0; i < a.length - 1; i++) {
    const g = a.slice(i, i + 2);
    grams.set(g, (grams.get(g) ?? 0) + 1);
  }
  let overlap = 0;
  for (let i = 0; i < b.length - 1; i++) {
    const g = b.slice(i, i + 2);
    const n = grams.get(g) ?? 0;
    if (n > 0) {
      grams.set(g, n - 1);
      overlap++;
    }
  }
  return (2 * overlap) / (a.length - 1 + (b.length - 1));
}

const stripZeros = (s: string) => s.replace(/^0+(?=.)/, "");

/** A catalog entry learned for this supplier: same article number, else the same receipt text. */
export function findCatalogEntry(
  line: { article_number: string | null; description: string },
  catalog: CatalogRow[],
): CatalogRow | null {
  const candidates = catalog.filter((c) => c.material_id);
  if (line.article_number) {
    const art = stripZeros(line.article_number.trim());
    const hit = candidates
      .filter((c) => c.article_number && stripZeros(c.article_number.trim()) === art)
      .sort((a, b) => b.created_at.localeCompare(a.created_at))[0];
    if (hit) return hit;
  }
  const text = line.description.trim().toLowerCase();
  return candidates.find((c) => c.receipt_name && c.receipt_name.trim().toLowerCase() === text) ?? null;
}

const UNIT_ALIASES: Record<string, "gram" | "kg" | "ml" | "l" | "piece"> = {
  gram: "gram", g: "gram", gr: "gram", gramm: "gram",
  kg: "kg", kilo: "kg", kilogram: "kg", kilogramm: "kg",
  ml: "ml", milliliter: "ml",
  l: "l", lt: "l", liter: "l", litre: "l",
  piece: "piece", pieces: "piece", pcs: "piece", stk: "piece", stück: "piece", stueck: "piece",
};

/**
 * Material units in one purchased unit, from the pack content Gemini read.
 * 2500 g into a material counted in grams → 2500; into kg → 2.5. Incompatible units → null.
 */
export function conversionFor(
  content: number | null,
  contentUnit: "g" | "ml" | "piece" | null,
  materialUnit: string,
): number | null {
  if (!content || content <= 0 || !contentUnit) return null;
  const unit = UNIT_ALIASES[materialUnit.trim().toLowerCase()];
  if (!unit) return null;
  if (contentUnit === "g") return unit === "gram" ? content : unit === "kg" ? content / 1000 : null;
  if (contentUnit === "ml") return unit === "ml" ? content : unit === "l" ? content / 1000 : null;
  return unit === "piece" ? content : null;
}

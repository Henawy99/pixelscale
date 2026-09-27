// supabase/functions/scan-expense/extract.ts
// Reads a supplier invoice / receipt (one document, one or more pages) with Gemini and returns
// structured data: supplier, invoice header, every line with pack size and a material suggestion.

export const MATERIAL_UNITS = ["gram", "ml", "piece"] as const;
export const MATERIAL_CATEGORIES = [
  "DRINKS",
  "MEAT",
  "BREAD",
  "FRUITS AND VEGETABLES",
  "SAUCES",
  "PACKAGING",
  "FINGERFOOD",
  "DESSERTS",
  "DAIRY",
  "DRY GOODS",
  "SUPPLIES",
] as const;
export const LINE_KINDS = ["product", "deposit", "empties_return", "fee", "discount", "other"] as const;

export type LineKind = (typeof LINE_KINDS)[number];

export interface ExtractedLine {
  position: number | null;
  article_number: string | null;
  description: string;
  quantity: number;
  unit: string | null;
  unit_price: number | null;
  line_total: number | null;
  vat_rate: number | null;
  kind: LineKind;
  content_per_unit: number | null;
  content_unit: "g" | "ml" | "piece" | null;
  material_id: string | null;
  material_confidence: number | null;
  new_material_name: string | null;
  new_material_unit: (typeof MATERIAL_UNITS)[number] | null;
  new_material_category: (typeof MATERIAL_CATEGORIES)[number] | null;
}

export interface ExtractedDocument {
  document_type: "invoice" | "receipt" | "delivery_note" | "credit_note" | "other";
  supplier: {
    name: string | null;
    address: string | null;
    postcode: string | null;
    city: string | null;
    phone: string | null;
    email: string | null;
    website: string | null;
    vat_id: string | null;
  };
  invoice_number: string | null;
  invoice_date: string | null;
  currency: string | null;
  prices_include_vat: boolean | null;
  lines: ExtractedLine[];
  totals: { net: number | null; vat: number | null; gross: number | null };
  pages: { received: number; stated_total: number | null; is_complete: boolean };
}

export interface MaterialRef {
  id: string;
  name: string;
  unit_of_measure: string;
  category: string | null;
}

export interface SupplierRef {
  name: string;
  ai_rules: string | null;
}

export interface DocumentFile {
  mimeType: string; // image/jpeg, image/png, application/pdf
  base64: string;
}

const S = (description?: string) => ({ type: "STRING", nullable: true, ...(description ? { description } : {}) });
const N = (description?: string) => ({ type: "NUMBER", nullable: true, ...(description ? { description } : {}) });

export const RESPONSE_SCHEMA = {
  type: "OBJECT",
  properties: {
    document_type: { type: "STRING", enum: ["invoice", "receipt", "delivery_note", "credit_note", "other"] },
    supplier: {
      type: "OBJECT",
      properties: {
        name: S("Company that issued the document (the seller)"),
        address: S("Street and number"),
        postcode: S(),
        city: S(),
        phone: S(),
        email: S(),
        website: S(),
        vat_id: S("Seller VAT / UID number, e.g. ATU65216688"),
      },
      required: ["name"],
    },
    invoice_number: S(),
    invoice_date: S("YYYY-MM-DD"),
    currency: S("ISO code, e.g. EUR"),
    prices_include_vat: { type: "BOOLEAN", nullable: true },
    lines: {
      type: "ARRAY",
      items: {
        type: "OBJECT",
        properties: {
          position: { type: "INTEGER", nullable: true },
          article_number: S(),
          description: { type: "STRING" },
          quantity: { type: "NUMBER" },
          unit: S(),
          unit_price: N(),
          line_total: N(),
          vat_rate: N(),
          kind: { type: "STRING", enum: [...LINE_KINDS] },
          content_per_unit: N(),
          content_unit: { type: "STRING", nullable: true, enum: ["g", "ml", "piece"] },
          material_id: S(),
          material_confidence: N(),
          new_material_name: S(),
          new_material_unit: { type: "STRING", nullable: true, enum: [...MATERIAL_UNITS] },
          new_material_category: { type: "STRING", nullable: true, enum: [...MATERIAL_CATEGORIES] },
        },
        required: ["description", "quantity", "kind"],
      },
    },
    totals: {
      type: "OBJECT",
      properties: { net: N(), vat: N(), gross: N() },
    },
    pages: {
      type: "OBJECT",
      properties: {
        received: { type: "INTEGER" },
        stated_total: { type: "INTEGER", nullable: true },
        is_complete: { type: "BOOLEAN" },
      },
      required: ["received", "is_complete"],
    },
  },
  required: ["document_type", "supplier", "lines", "totals", "pages"],
};

export function buildPrompt(materials: MaterialRef[], suppliers: SupplierRef[]): string {
  const materialLines = materials
    .map((m) => `${m.id} | ${m.name.trim()} | ${m.unit_of_measure} | ${m.category ?? ""}`)
    .join("\n");
  const supplierLines = suppliers
    .map((s) => `- ${s.name}${s.ai_rules ? `: ${s.ai_rules.replace(/\s+/g, " ").trim()}` : ""}`)
    .join("\n");

  return `You read supplier invoices and receipts for a restaurant kitchen in Salzburg, Austria (Devils Smash Burger and its sister brands). Documents are usually German. All attached pages belong to ONE document; pages may be in any order.

Return JSON that matches the response schema.

SUPPLIER
- supplier = the company that ISSUED the document (the seller). Never the customer (e.g. "DEVEL'S SMASH BURGER", "Devils Smash Burger", "Minnesheimer Str").
- vat_id = the seller's UID / VAT number (e.g. "ATU65216688").

HEADER
- invoice_number = Rechnung / Beleg / Invoice number. invoice_date = document date as YYYY-MM-DD.
- prices_include_vat = true if unit prices are gross (typical for supermarket receipts), false if net with VAT added at the end (typical wholesale invoices).

LINES (every article line, in order, across all pages)
- description: the product text, multi-line descriptions joined with spaces, WITHOUT the article number.
- article_number: "Art.-Nr.", "Artikelnummer", "Art.Nr" value; if there is none but an EAN/GTIN is printed, use that.
- quantity = number of purchased units ("Menge"); unit = the purchased unit as printed (Karton, Packung, Sack, Kiste, Tray, Kanister, Tube, Glas, PET, kg, Stk., ...).
- unit_price = price per purchased unit as printed; line_total = the line amount as printed.
- Returns and credits: if a line amount is negative, make BOTH quantity and line_total negative.
- vat_rate in percent (10, 20, 0, ...).
- kind: "product" = goods the kitchen stocks (food, drinks, packaging, cleaning and paper supplies); "deposit" = Pfand / deposit charges (e.g. "EINWEG - PFAND"); "empties_return" = returned empties or crates (Leergut, Leerkiste); "fee" = delivery / service / handling fees; "discount" = rebates; "other" = anything else.
- content_per_unit + content_unit: how much ONE purchased unit contains, read from the description:
  "2,5kg Sack" → 2500 g · "10.00 Lt Öl Kanister" → 10000 ml · "875ml" → 875 ml · "6Kg Kiste" → 6000 g · unit "kg" → 1000 g ·
  "108 Stk. Karton" → 108 piece · "24/0.33 Fritz Kola" per Kiste/Tray → 24 piece · "Scheiben 1033g" per Packung → 1033 g ·
  "(5 SACK 1 KARTON)" only tells how many bags fit in a carton; if the purchased unit is the bag, use the bag content.
  If the matching material (below) is counted in pieces, give pieces per purchased unit (e.g. burger buns "20 Stk Karton" → 20 piece).
  null when the content cannot be read.
- material_id: the id of the best matching material from MATERIALS (same product; brand or pack size may differ), or null if none fits. Deposits, empties, fees and discounts never get a material. material_confidence 0..1.
- new_material_name / new_material_unit / new_material_category: only when kind is "product" and material_id is null. Short, clear inventory name (e.g. "Sonnenblumenöl", "Dürüm Tortilla 30cm", "Cheddar Scheiben"), unit gram | ml | piece, category from the schema enum (DAIRY for cheese/milk/cream, DRY GOODS for oil/vinegar/spices/flour/canned goods, SUPPLIES for cleaning, paper, bags, gloves).

TOTALS AND PAGES
- totals.net / totals.vat / totals.gross (amount payable) as printed on the document; null if not visible (e.g. the last page is missing and only "Übertrag" is shown).
- pages.received = number of pages you were given; pages.stated_total from "Seite x von y" if printed; pages.is_complete = false if a page is clearly missing.

Numbers in JSON use "." as decimal separator ("24,99" → 24.99). Never invent lines or amounts.

MATERIALS (id | name | unit | category):
${materialLines}

KNOWN SUPPLIERS (with notes on their documents):
${supplierLines}`;
}

export interface ExtractResult {
  doc: ExtractedDocument;
  model: string;
  ms: number;
  usage: unknown;
}

/** Newest first; the next one is tried when a model is overloaded or unavailable. */
export const DEFAULT_MODELS = ["gemini-3.8-flash", "gemini-3.5-flash", "gemini-2.5-flash"];

export async function extractDocument(
  files: DocumentFile[],
  materials: MaterialRef[],
  suppliers: SupplierRef[],
  apiKey: string,
  models: string[] = DEFAULT_MODELS,
): Promise<ExtractResult> {
  const started = Date.now();
  const contents = [
    {
      role: "user",
      parts: [
        { text: buildPrompt(materials, suppliers) },
        ...files.map((f) => ({ inline_data: { mime_type: f.mimeType, data: f.base64 } })),
      ],
    },
  ];

  const errors: string[] = [];
  for (const model of models) {
    const body = {
      contents,
      generationConfig: {
        temperature: 0,
        responseMimeType: "application/json",
        responseSchema: RESPONSE_SCHEMA,
        maxOutputTokens: 32768,
        // Reading a document needs little reasoning: "low" is ~3x faster with the same result.
        ...(model.startsWith("gemini-3") ? { thinkingConfig: { thinkingLevel: "low" } } : {}),
      },
    };
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
    for (let attempt = 1; attempt <= 2; attempt++) {
      const resp = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (resp.ok) {
        const data = await resp.json();
        const text: string | undefined = data.candidates?.[0]?.content?.parts
          ?.map((p: { text?: string }) => p.text ?? "")
          .join("");
        if (!text) {
          errors.push(`${model}: no content (${data.candidates?.[0]?.finishReason ?? "unknown"})`);
          break;
        }
        const doc = normalize(JSON.parse(text), materials);
        return { doc, model, ms: Date.now() - started, usage: data.usageMetadata };
      }
      const detail = `${model}: ${resp.status} ${(await resp.text()).slice(0, 200)}`;
      errors.push(detail);
      // Overloaded or rate limited: retry once, then move on to the next model.
      if (![429, 500, 503].includes(resp.status)) break;
      if (attempt === 1) await new Promise((r) => setTimeout(r, 1500));
    }
  }
  throw new Error(`Gemini could not read the document: ${errors.join(" | ")}`);
}

/** Clean up model output: known material ids only, signed returns, trimmed strings. */
export function normalize(raw: any, materials: MaterialRef[]): ExtractedDocument {
  const ids = new Set(materials.map((m) => m.id));
  const str = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);
  const num = (v: unknown) => (typeof v === "number" && Number.isFinite(v) ? v : null);

  const lines: ExtractedLine[] = (Array.isArray(raw?.lines) ? raw.lines : []).map((l: any) => {
    let quantity = num(l.quantity) ?? 0;
    const total = num(l.line_total);
    if (total !== null && total < 0 && quantity > 0) quantity = -quantity;
    const kind: LineKind = LINE_KINDS.includes(l.kind) ? l.kind : "other";
    const materialId = kind === "product" && str(l.material_id) && ids.has(l.material_id) ? l.material_id : null;
    return {
      position: num(l.position),
      article_number: str(l.article_number),
      description: str(l.description) ?? "",
      quantity,
      unit: str(l.unit),
      unit_price: num(l.unit_price),
      line_total: total,
      vat_rate: num(l.vat_rate),
      kind,
      content_per_unit: num(l.content_per_unit) && l.content_per_unit > 0 ? l.content_per_unit : null,
      content_unit: ["g", "ml", "piece"].includes(l.content_unit) ? l.content_unit : null,
      material_id: materialId,
      material_confidence: materialId ? num(l.material_confidence) : null,
      new_material_name: kind === "product" && !materialId ? str(l.new_material_name) : null,
      new_material_unit: MATERIAL_UNITS.includes(l.new_material_unit) ? l.new_material_unit : null,
      new_material_category: MATERIAL_CATEGORIES.includes(l.new_material_category) ? l.new_material_category : null,
    };
  });

  return {
    document_type: ["invoice", "receipt", "delivery_note", "credit_note", "other"].includes(raw?.document_type)
      ? raw.document_type
      : "other",
    supplier: {
      name: str(raw?.supplier?.name),
      address: str(raw?.supplier?.address),
      postcode: str(raw?.supplier?.postcode),
      city: str(raw?.supplier?.city),
      phone: str(raw?.supplier?.phone),
      email: str(raw?.supplier?.email),
      website: str(raw?.supplier?.website),
      vat_id: str(raw?.supplier?.vat_id)?.replace(/\s+/g, "").toUpperCase() ?? null,
    },
    invoice_number: str(raw?.invoice_number),
    invoice_date: /^\d{4}-\d{2}-\d{2}$/.test(raw?.invoice_date ?? "") ? raw.invoice_date : null,
    currency: str(raw?.currency) ?? "EUR",
    prices_include_vat: typeof raw?.prices_include_vat === "boolean" ? raw.prices_include_vat : null,
    lines,
    totals: { net: num(raw?.totals?.net), vat: num(raw?.totals?.vat), gross: num(raw?.totals?.gross) },
    pages: {
      received: num(raw?.pages?.received) ?? 1,
      stated_total: num(raw?.pages?.stated_total),
      is_complete: raw?.pages?.is_complete !== false,
    },
  };
}

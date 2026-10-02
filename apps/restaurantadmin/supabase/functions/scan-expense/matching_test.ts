// Run: deno test supabase/functions/scan-expense/matching_test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { compactCompany, conversionFor, findCatalogEntry, matchSupplier, priceRuleMaterials } from "./matching.ts";

const suppliers = [
  { id: "sg", name: "S&G Import Export", vat_id: null, aliases: [] },
  { id: "metro", name: "METRO", vat_id: null, aliases: [] },
  { id: "ist", name: "Istanbul Metzgerei", vat_id: "ATU11111111", aliases: [] },
];

Deno.test("same company written differently is recognised", () => {
  assertEquals(compactCompany("SG Import & Export GmbH"), compactCompany("S&G Import Export"));
  assertEquals(matchSupplier({ name: "SG Import & Export GmbH", vat_id: null }, suppliers).supplier_id, "sg");
  assertEquals(matchSupplier({ name: "SG Import & Export GmbH", vat_id: null }, suppliers).status, "matched");
});

Deno.test("chain name with suffixes matches the short supplier name", () => {
  const m = matchSupplier({ name: "METRO Cash & Carry Österreich GmbH", vat_id: null }, suppliers);
  assertEquals(m.supplier_id, "metro");
  assertEquals(m.status, "matched");
});

Deno.test("VAT id wins over the name", () => {
  assertEquals(matchSupplier({ name: "Something Else", vat_id: "atu 11111111" }, suppliers).supplier_id, "ist");
});

Deno.test("an unknown supplier is reported as unknown", () => {
  const m = matchSupplier({ name: "Kröswang GmbH", vat_id: "ATU99999999" }, suppliers);
  assertEquals(m.status, "unknown");
  assertEquals(m.supplier_id, null);
});

Deno.test("catalog lookup by article number ignores leading zeros, then by receipt text", () => {
  const catalog = [
    { id: "c1", article_number: "194", receipt_name: "x", material_id: "tortilla", conversion_ratio: 108, created_at: "2026-01-01" },
    { id: "c2", article_number: null, receipt_name: "Eissalat Kiste", material_id: "salat", conversion_ratio: null, created_at: "2026-01-01" },
    { id: "c3", article_number: "4752", receipt_name: "Pommes", material_id: null, conversion_ratio: null, created_at: "2026-01-01" },
  ];
  assertEquals(findCatalogEntry({ article_number: "0194", description: "KALE Dürüm" }, catalog)?.id, "c1");
  assertEquals(findCatalogEntry({ article_number: null, description: "eissalat kiste " }, catalog)?.id, "c2");
  // Entries without a material are not a match.
  assertEquals(findCatalogEntry({ article_number: "4752", description: "Pommes" }, catalog), null);
});

Deno.test("pack content converts into the material's unit", () => {
  assertEquals(conversionFor(2500, "g", "gram"), 2500);
  assertEquals(conversionFor(2500, "g", "kg"), 2.5);
  assertEquals(conversionFor(10000, "ml", "ml"), 10000);
  assertEquals(conversionFor(108, "piece", "piece"), 108);
  assertEquals(conversionFor(875, "ml", "gram"), null);
  assertEquals(conversionFor(null, "g", "gram"), null);
});

const homsGate = { text: "Grundpreiseingabe", split: 8, low: "chicken", high: "minced", conversion: 1000 };
const scale = (unit_price: number, quantity: number) => ({
  description: "Grundpreiseingabe",
  quantity,
  unit_price,
  line_total: Math.round(unit_price * quantity * 100) / 100,
});

Deno.test("price rule: a receipt with one price is matched by the split", () => {
  assertEquals(priceRuleMaterials([scale(6, 9.025), scale(6, 10.88), scale(6, 10.03)], homsGate), ["chicken", "chicken", "chicken"]);
  assertEquals(priceRuleMaterials([scale(10, 6.92), scale(10, 7.88)], homsGate), ["minced", "minced"]);
});

Deno.test("price rule: with two prices the dearer is always the high product", () => {
  // Both above the split: still the cheaper one is chicken.
  assertEquals(priceRuleMaterials([scale(9, 5), scale(11.5, 4)], homsGate), ["chicken", "minced"]);
});

Deno.test("price rule: other lines and lines without a price are left alone", () => {
  const lines = [scale(6, 2), { description: "Tragetasche", quantity: 1, unit_price: 0.2, line_total: 0.2 },
    { description: "Grundpreiseingabe", quantity: null, unit_price: null, line_total: null }];
  assertEquals(priceRuleMaterials(lines, homsGate), ["chicken", null, null]);
});

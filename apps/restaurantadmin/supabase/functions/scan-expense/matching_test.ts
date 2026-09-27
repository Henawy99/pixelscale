// Run: deno test supabase/functions/scan-expense/matching_test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { compactCompany, conversionFor, findCatalogEntry, matchSupplier } from "./matching.ts";

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

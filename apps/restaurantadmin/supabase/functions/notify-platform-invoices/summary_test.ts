// Run: deno test supabase/functions/notify-platform-invoices/summary_test.ts
import { assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { bankPayout, buildSummary, lieferandoPayout, shortBrand } from "./summary.ts";

const inv = (restaurant: string, payout: number | null, carried = 0, date = "2026-09-27") => ({
  restaurant_name: restaurant,
  invoice_date: date,
  period_start: "2026-09-20",
  period_end: "2026-09-26",
  payout_amount: payout,
  carried_over: carried,
});

Deno.test("bank payout nets what earlier invoices left unpaid", () => {
  assertEquals(bankPayout({ payout_amount: 840.3, carried_over: 63.71 }), 776.59);
  assertEquals(bankPayout({ payout_amount: 363.22, carried_over: 426.93 }), 0);
  assertEquals(bankPayout({ payout_amount: null, carried_over: null }), 0);
});

Deno.test("Lieferando payout line is read from the PDF text", () => {
  const text = "Rechnungsausgleich 360276081 € 617,00\nAuszahlung auf das Bankkonto AT892040400043641471 z.Hd. Elmetwalli Samir € 1.962,17";
  assertEquals(lieferandoPayout(text), 1962.17);
  assertEquals(lieferandoPayout("Rechnungsausgleich 360281611 € 67,91"), 0);
});

Deno.test("weekly Lieferando summary lists the paying restaurants, biggest first", () => {
  const s = buildSummary("lieferando", [
    inv("Crispy Chicken Lab", 1134.21),
    inv("Devil's Smash Burger 5023", 1962.17),
    inv("Tacotastic - French Tacos 5023 Salzburg", 0),
  ]);
  assertEquals(s.title, "Lieferando invoices are ready");
  assertEquals(s.body, "20–26 Sep: payout € 3.096,38. Devil's € 1.962,17 · Crispy € 1.134,21");
});

Deno.test("Foodora summary says when the money arrives", () => {
  const s = buildSummary("foodora", [{ ...inv("Devil's Smash Burger", 456.99, 0, "2026-09-22"), period_start: "2026-09-16", period_end: "2026-09-22" }]);
  assertEquals(s.body, "16–22 Sep: payout € 456,99 (arrives ~6 Oct). Devil's € 456,99");
});

Deno.test("a back-fill of many weeks becomes one short line", () => {
  const rows = ["2025-10-05", "2025-10-12", "2025-12-28"].map((d) => inv("Devil's", 100, 0, d));
  const s = buildSummary("lieferando", rows);
  assertEquals(s.title, "Lieferando: 3 older invoices downloaded");
  assertEquals(s.body, "Oct 2025 – Dec 2025: € 300,00 paid out in total.");
});

Deno.test("a week across two months shows both", () => {
  const s = buildSummary("lieferando", [{ ...inv("Devil's", 10), period_start: "2026-09-27", period_end: "2026-10-03" }]);
  assertEquals(s.body.startsWith("27 Sep – 3 Oct: payout"), true);
});

Deno.test("brand names are shortened", () => {
  assertEquals(shortBrand("Pasta Factory Wildenhoferstraße"), "Stack'd");
  assertEquals(shortBrand("The Bowl Spot"), "Bowl Spot");
});

// supabase/functions/notify-platform-invoices/summary.ts
// Pure helpers: what a delivery-platform invoice paid out, the Lieferando payout line, and the
// one push message that announces a batch of new invoices.

export interface NewInvoice {
  restaurant_name: string | null;
  invoice_date: string; // YYYY-MM-DD
  period_start: string | null;
  period_end: string | null;
  payout_amount: number | null;
  carried_over: number | null;
}

/**
 * Money that reaches the bank for one invoice. Foodora nets what earlier invoices left unpaid
 * (carried_over) against this period's payout; Lieferando rows carry 0 there.
 */
export function bankPayout(i: Pick<NewInvoice, "payout_amount" | "carried_over">): number {
  return Math.max(Math.round(((i.payout_amount ?? 0) - (i.carried_over ?? 0)) * 100) / 100, 0);
}

/** "Auszahlung auf das Bankkonto AT89… z.Hd. … € 1.962,17" → 1962.17; no such line → 0. */
export function lieferandoPayout(pdfText: string): number {
  const m = pdfText.replace(/\s+/g, " ").match(/Auszahlung auf das Bankkonto \S+.*?€\s*(-?[\d.]+,\d{2})/);
  return m ? Number(m[1].replace(/\./g, "").replace(",", ".")) : 0;
}

const BRANDS: [RegExp, string][] = [
  [/devil/i, "Devil's"],
  [/crispy/i, "Crispy"],
  [/taco/i, "Tacotastic"],
  [/bowl/i, "Bowl Spot"],
  [/stack|pasta/i, "Stack'd"],
];

export function shortBrand(restaurantName: string | null): string {
  if (!restaurantName) return "Other";
  return BRANDS.find(([re]) => re.test(restaurantName))?.[1] ?? restaurantName;
}

const euro = (n: number) =>
  new Intl.NumberFormat("de-AT", { style: "currency", currency: "EUR" }).format(n).replace(/ /g, " ");
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
const parts = (iso: string) => ({ d: Number(iso.slice(8, 10)), m: MONTHS[Number(iso.slice(5, 7)) - 1], y: iso.slice(0, 4) });
const day = (iso: string) => `${parts(iso).d} ${parts(iso).m}`;
const month = (iso: string) => `${parts(iso).m} ${parts(iso).y}`;
/** "20–26 Sep", or "29 Sep – 5 Oct" across months. */
const span = (from: string, to: string) =>
  from.slice(0, 7) === to.slice(0, 7) ? `${parts(from).d}–${day(to)}` : `${day(from)} – ${day(to)}`;
const addDays = (iso: string, n: number) => new Date(Date.parse(`${iso}T12:00:00Z`) + n * 86_400_000).toISOString().slice(0, 10);

/** One push message for the invoices a platform added since the last announcement. */
export function buildSummary(platform: string, invoices: NewInvoice[]): { title: string; body: string } {
  const name = platform === "foodora" ? "Foodora" : "Lieferando";
  const total = invoices.reduce((s, i) => s + bankPayout(i), 0);
  const dates = [...new Set(invoices.map((i) => i.invoice_date))].sort();

  // A back-fill of older weeks: one line, not a breakdown.
  if (dates.length > 2) {
    const range = month(dates[0]) === month(dates[dates.length - 1])
      ? month(dates[0])
      : `${month(dates[0])} – ${month(dates[dates.length - 1])}`;
    return {
      title: `${name}: ${invoices.length} older invoices downloaded`,
      body: `${range}: ${euro(total)} paid out in total.`,
    };
  }

  const starts = invoices.map((i) => i.period_start).filter((d): d is string => !!d).sort();
  const ends = invoices.map((i) => i.period_end).filter((d): d is string => !!d).sort();
  const period = starts.length && ends.length
    ? span(starts[0], ends[ends.length - 1])
    : day(dates[dates.length - 1]);

  const byBrand = new Map<string, number>();
  for (const i of invoices) {
    const brand = shortBrand(i.restaurant_name);
    byBrand.set(brand, (byBrand.get(brand) ?? 0) + bankPayout(i));
  }
  const paid = [...byBrand.entries()].filter(([, v]) => v > 0).sort((a, b) => b[1] - a[1]);
  const arrives = platform === "foodora" ? ` (arrives ~${day(addDays(dates[dates.length - 1], 14))})` : "";

  const body = total > 0
    ? `${period}: payout ${euro(total)}${arrives}. ${paid.map(([b, v]) => `${b} ${euro(v)}`).join(" · ")}`
    : `${period}: no payout this time (fees were settled from your online payments).`;
  return { title: `${name} invoices are ready`, body };
}

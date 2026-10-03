// supabase/functions/notify-platform-invoices/index.ts
// Called every 10 minutes by pg_cron (platform_invoice_notify_tick). Two jobs:
//   1. Lieferando payouts: the Partner Hub list only has the fee invoice, the payout is printed in
//      the PDF ("Auszahlung auf das Bankkonto … €"). Reads it for rows that have a PDF but no
//      payout yet (also back-fills older rows, a batch per run) — carried_over is 0 for Lieferando.
//   2. One push per platform when the VPS jobs have added invoices (weekly run, or a back-fill):
//      once the batch has stopped arriving, sums what each restaurant gets paid out. Not between
//      23:00 and 08:00 in Vienna — a night-time batch is announced in the morning.
// Auth: service-role key only.

import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { extractText, getDocumentProxy } from "https://esm.sh/unpdf@0.12.1";
import { sendPushNotification } from "../_shared/fcm.ts";
import { buildSummary, lieferandoPayout, type NewInvoice } from "./summary.ts";

const BUCKET = "platform-invoices";
const PDFS_PER_RUN = 25;
/** The VPS jobs post one account after another; a batch is complete once nothing arrived for this long. */
const QUIET_MS = 8 * 60_000;
/** Notify anyway if some PDFs never arrive. */
const GIVE_UP_MS = 60 * 60_000;
/** Invoice news can wait: nothing is sent between 23:00 and 08:00 in Vienna. */
const QUIET_HOURS = { from: 23, to: 8 };

function viennaHour(now: number): number {
  return Number(new Intl.DateTimeFormat("en-GB", { hour: "numeric", hour12: false, timeZone: "Europe/Vienna" }).format(now));
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

async function readLieferandoPayouts(db: SupabaseClient): Promise<number> {
  const { data: rows } = await db
    .from("platform_invoices")
    .select("id, pdf_path")
    .eq("platform", "lieferando")
    .not("pdf_path", "is", null)
    .is("payout_amount", null)
    // Invoices still to be announced first, then the newest.
    .order("notified_at", { ascending: true, nullsFirst: true })
    .order("invoice_date", { ascending: false })
    .limit(PDFS_PER_RUN);
  let done = 0;
  for (const row of rows ?? []) {
    try {
      const { data: blob, error } = await db.storage.from(BUCKET).download(row.pdf_path);
      if (error || !blob) throw new Error(error?.message ?? "missing");
      const pdf = await getDocumentProxy(new Uint8Array(await blob.arrayBuffer()));
      const { text } = await extractText(pdf, { mergePages: true });
      await db
        .from("platform_invoices")
        .update({ payout_amount: lieferandoPayout(String(text)), carried_over: 0 })
        .eq("id", row.id);
      done++;
    } catch (e) {
      console.error(`[notify-platform-invoices] ${row.pdf_path}: ${(e as Error).message}`);
    }
  }
  return done;
}

async function announce(db: SupabaseClient, platform: string, now: number): Promise<string> {
  const { data: pending } = await db
    .from("platform_invoices")
    .select("id, restaurant_name, invoice_date, period_start, period_end, payout_amount, carried_over, pdf_path, fetched_at")
    .eq("platform", platform)
    .is("notified_at", null);
  if (!pending?.length) return "nothing new";

  const { data: latest } = await db
    .from("platform_invoices")
    .select("fetched_at")
    .eq("platform", platform)
    .order("fetched_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  const quietFor = now - Date.parse(latest?.fetched_at ?? new Date(0).toISOString());
  if (quietFor < QUIET_MS) return "batch still arriving";

  const incomplete = pending.filter((r) => !r.pdf_path || r.payout_amount === null);
  if (incomplete.length > 0 && quietFor < GIVE_UP_MS) return `waiting for ${incomplete.length} PDFs`;

  const hour = viennaHour(now);
  if (hour >= QUIET_HOURS.from || hour < QUIET_HOURS.to) return `${pending.length} ready, held until 08:00`;

  const { title, body } = buildSummary(platform, pending as NewInvoice[]);
  const sent = await sendPushNotification(db, { title, body, data: { type: "platform_invoices", platform } });
  await db
    .from("platform_invoices")
    .update({ notified_at: new Date(now).toISOString() })
    .in("id", pending.map((r) => r.id));
  return `${pending.length} invoices announced to ${sent.success} devices: ${body}`;
}

Deno.serve(async (req) => {
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if ((req.headers.get("Authorization") ?? "") !== `Bearer ${key}`) return json({ error: "Unauthorized" }, 401);
  const db = createClient(Deno.env.get("SUPABASE_URL") ?? "", key);
  const now = Date.now();

  const payoutsRead = await readLieferandoPayouts(db);
  const result: Record<string, string> = {};
  for (const platform of ["lieferando", "foodora"]) {
    result[platform] = await announce(db, platform, now);
  }
  console.log(`[notify-platform-invoices] payouts read: ${payoutsRead}`, result);
  return json({ payoutsRead, ...result });
});

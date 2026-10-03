// supabase/functions/scan-expense/index.ts
// Reads a scanned supplier invoice and prepares it for review:
//   photos/PDF in storage → Gemini → supplier + line matching → purchases / purchase_items.
// Booking into inventory happens later, after review, via the book_expense() RPC.
//
// Body: { paths: string[] }            new expense from uploaded pages (bucket "scanned-receipts")
//    or { purchase_id: string }         read an existing expense again (e.g. after a failure)
//    + { mode: "record" }               optional: history only — status "recorded", never offered for stock
//    + { wait: true }                   optional: answer only when reading is done (scripts)
//
// By default it answers right away with { purchase_id, status: "analyzing" } and reads in the
// background: Gemini can need longer than the 150 s a request may stay open. The app polls the
// expense until it leaves "analyzing".

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.43.4";
import { encodeBase64 } from "https://deno.land/std@0.208.0/encoding/base64.ts";
import { corsHeaders } from "../_shared/cors.ts";
import { sendPushNotification } from "../_shared/fcm.ts";
import { extractDocument, ExtractError, type DocumentFile, type ExtractedDocument } from "./extract.ts";
import {
  conversionFor,
  findCatalogEntry,
  matchSupplier,
  priceRuleMaterials,
  type CatalogRow,
  type PriceRule,
  type SupplierRow,
} from "./matching.ts";

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

const BUCKET = "scanned-receipts";
const STAFF_ROLES = ["admin", "manager", "worker"];
/** A function may run 150 s in total; leave room to save the result or the failure. */
const BUDGET_MS = 138_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function mimeFor(path: string): string {
  const ext = path.split(".").pop()?.toLowerCase();
  if (ext === "pdf") return "application/pdf";
  if (ext === "png") return "image/png";
  if (ext === "webp") return "image/webp";
  if (ext === "heic" || ext === "heif") return "image/heic";
  return "image/jpeg";
}

interface Warning {
  code: string;
  message: string;
}

const money = (n: number) => `€${n.toFixed(2).replace(".", ",")}`;

/** Tells the admin phones that a scanned invoice is read (or could not be). Never throws. */
async function notifyScan(admin: SupabaseClient, title: string, body: string, purchaseId: string) {
  try {
    await sendPushNotification(admin, { title, body, data: { type: "expense", expense_id: purchaseId } });
  } catch (e) {
    console.error("[scan-expense] push failed:", (e as Error).message);
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  const deadline = Date.now() + BUDGET_MS;

  const admin = createClient(Deno.env.get("SUPABASE_URL") ?? "", Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "");

  // Staff only (or a trusted server-side call with the service key).
  const jwt = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  let userId: string | null = null;
  if (jwt !== Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")) {
    const { data: userData } = await admin.auth.getUser(jwt);
    const user = userData?.user;
    if (!user) return json({ error: "Please sign in again." }, 401);
    const { data: profile } = await admin.from("profiles").select("role").eq("id", user.id).maybeSingle();
    if (!STAFF_ROLES.includes(profile?.role ?? "")) return json({ error: "Not allowed" }, 403);
    userId = user.id;
  }

  let body: { paths?: string[]; purchase_id?: string; mode?: string; wait?: boolean } = {};
  try {
    body = await req.json();
  } catch {
    return json({ error: "Invalid request" }, 400);
  }

  // 1. The expense row (created first so a failure is visible in the list and can be retried).
  let purchaseId = body.purchase_id ?? null;
  let paths: string[] = [];
  if (purchaseId) {
    const { data: existing } = await admin.from("purchases").select("id, status, document_paths").eq("id", purchaseId).maybeSingle();
    if (!existing) return json({ error: "Expense not found" }, 404);
    if (existing.status === "booked") return json({ error: "This expense is already in the inventory" }, 409);
    paths = existing.document_paths ?? [];
    await admin
      .from("purchases")
      .update({ status: "analyzing", error: null, updated_at: new Date().toISOString() })
      .eq("id", purchaseId);
  } else {
    paths = (body.paths ?? []).filter((p) => typeof p === "string" && p.length > 0);
    if (paths.length === 0) return json({ error: "No pages uploaded" }, 400);
    const { data: created, error } = await admin
      .from("purchases")
      .insert({ status: "analyzing", document_paths: paths, created_by: userId, notes: "Scanned expense" })
      .select("id")
      .single();
    if (error) return json({ error: error.message }, 500);
    purchaseId = created.id;
  }
  if (paths.length === 0) return json({ error: "This expense has no document pages" }, 400);

  const work = readExpense(admin, purchaseId!, paths, body.mode === "record", deadline);
  if (body.wait || typeof EdgeRuntime === "undefined") {
    const result = await work;
    return json(result, result.error ? 500 : 200);
  }
  EdgeRuntime.waitUntil(work);
  return json({ purchase_id: purchaseId, status: "analyzing" });
});

/** Gemini → supplier and line matching → saved for review. Never throws: failures are saved on the expense. */
async function readExpense(
  admin: SupabaseClient,
  purchaseId: string,
  paths: string[],
  recordOnly: boolean,
  deadline: number,
): Promise<{ purchase_id: string; status: string; error?: string }> {
  try {
    // 2. Pages from storage.
    const files: DocumentFile[] = [];
    for (const path of paths) {
      const { data: blob, error } = await admin.storage.from(BUCKET).download(path);
      if (error || !blob) throw new Error(`Could not load page ${path}: ${error?.message ?? "missing"}`);
      files.push({ mimeType: mimeFor(path), base64: encodeBase64(new Uint8Array(await blob.arrayBuffer())) });
    }

    // 3. What the model needs to know: current materials and suppliers.
    const [{ data: materials }, { data: suppliers }] = await Promise.all([
      admin.from("material").select("id, name, unit_of_measure, category").order("name"),
      admin.from("suppliers").select("id, name, vat_id, aliases, ai_rules, price_rule").order("name"),
    ]);
    const materialById = new Map((materials ?? []).map((m) => [m.id, m]));

    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) throw new Error("Gemini is not configured on the server");
    const { doc, model, ms, attempts } = await extractDocument(
      files,
      materials ?? [],
      suppliers ?? [],
      apiKey,
      undefined,
      deadline,
    );

    // 4. Supplier.
    const supplierMatch = matchSupplier(doc.supplier, (suppliers ?? []) as SupplierRow[]);
    const supplierId = supplierMatch.status === "matched" ? supplierMatch.supplier_id : null;
    const supplierName = supplierId
      ? (suppliers ?? []).find((s) => s.id === supplierId)?.name ?? doc.supplier.name
      : doc.supplier.name;

    // A certain match teaches the supplier its VAT id, so it is recognised even if the name changes.
    const matchedRow = (suppliers ?? []).find((s) => s.id === supplierId);
    if (matchedRow && !matchedRow.vat_id && doc.supplier.vat_id && supplierMatch.score >= 0.95) {
      await admin.from("suppliers").update({ vat_id: doc.supplier.vat_id }).eq("id", matchedRow.id).is("vat_id", null);
    }

    let catalog: CatalogRow[] = [];
    if (supplierId) {
      const { data } = await admin
        .from("purchase_catalog_items")
        .select("id, article_number, receipt_name, material_id, conversion_ratio, created_at")
        .eq("supplier_id", supplierId);
      catalog = (data ?? []) as CatalogRow[];
    }

    // 5. Lines: the supplier's price rule, then the learned catalog entry, then Gemini's suggestion.
    const priceRule = (matchedRow?.price_rule ?? null) as PriceRule | null;
    const ruled = priceRule ? priceRuleMaterials(doc.lines, priceRule) : [];
    const items = doc.lines.map((line, index) => {
      const learned = findCatalogEntry(line, catalog);
      const ruleMaterial = ruled[index] && materialById.has(ruled[index]!) ? ruled[index]! : null;
      let materialId: string | null = null;
      let conversion: number | null = null;
      let source: string | null = null;
      let confidence: number | null = null;
      if (ruleMaterial) {
        materialId = ruleMaterial;
        conversion = priceRule!.conversion;
        source = "rule";
        confidence = 1;
      } else if (learned?.material_id && materialById.has(learned.material_id)) {
        materialId = learned.material_id;
        const unit = materialById.get(materialId)!.unit_of_measure;
        conversion = learned.conversion_ratio ?? conversionFor(line.content_per_unit, line.content_unit, unit);
        source = "catalog";
        confidence = 1;
      } else if (line.material_id) {
        materialId = line.material_id;
        const unit = materialById.get(materialId)!.unit_of_measure;
        conversion = conversionFor(line.content_per_unit, line.content_unit, unit);
        source = "ai";
        confidence = line.material_confidence;
      }
      return {
        purchase_id: purchaseId,
        position: line.position,
        raw_name: line.description,
        item_number: line.article_number,
        quantity: line.quantity,
        unit: line.unit,
        unit_price: line.unit_price,
        total_item_price: line.line_total,
        vat_rate: line.vat_rate,
        kind: ruleMaterial ? "product" : line.kind,
        content_per_unit: line.content_per_unit,
        content_unit: line.content_unit,
        material_id: materialId,
        conversion_ratio: conversion,
        base_unit: materialId ? materialById.get(materialId)!.unit_of_measure : null,
        match_source: source,
        match_confidence: confidence,
        purchase_catalog_item_id: ruleMaterial ? null : learned?.id ?? null,
        stock: (!!ruleMaterial || line.kind === "product") && !!materialId && !!conversion && conversion > 0,
        suggestion: materialId
          ? null
          : line.kind === "product"
            ? { name: line.new_material_name, unit: line.new_material_unit, category: line.new_material_category }
            : null,
      };
    });

    // 6. Things the reviewer should know.
    const warnings: Warning[] = [];
    if (doc.document_type === "other") {
      warnings.push({ code: "not_invoice", message: "This does not look like an invoice or receipt." });
    }
    if (!doc.pages.is_complete) {
      const stated = doc.pages.stated_total ? ` (${doc.pages.received} of ${doc.pages.stated_total} pages)` : "";
      warnings.push({ code: "missing_pages", message: `A page seems to be missing${stated}. The invoice total is not visible.` });
    }
    const linesSum = Math.round(doc.lines.reduce((s, l) => s + (l.line_total ?? 0), 0) * 100) / 100;
    const expected = doc.prices_include_vat ? doc.totals.gross : doc.totals.net;
    if (expected !== null && doc.lines.length > 0 && Math.abs(linesSum - expected) > Math.max(0.05, Math.abs(expected) * 0.005)) {
      warnings.push({
        code: "totals_mismatch",
        message: `The lines add up to ${money(linesSum)}, the invoice says ${money(expected)}. Check for a missed or misread line.`,
      });
    }
    if (supplierId && doc.invoice_number) {
      const { data: dup } = await admin
        .from("purchases")
        .select("id, created_at, status")
        .eq("supplier_id", supplierId)
        .eq("invoice_number", doc.invoice_number)
        .neq("id", purchaseId)
        .in("status", ["needs_review", "booked"])
        .limit(1)
        .maybeSingle();
      if (dup) {
        warnings.push({
          code: "duplicate",
          message: `This invoice was already scanned on ${new Date(dup.created_at).toLocaleDateString("de-AT")}${dup.status === "booked" ? " and is in the inventory" : ""}.`,
        });
      }
    }

    // 7. Save (replace lines on a re-read).
    await admin.from("purchase_items").delete().eq("purchase_id", purchaseId).eq("booked", false);
    if (items.length > 0) {
      const { error } = await admin.from("purchase_items").insert(items);
      if (error) throw new Error(`Saving lines failed: ${error.message}`);
    }

    const gross = doc.totals.gross ?? (doc.totals.net !== null && doc.totals.vat !== null ? doc.totals.net + doc.totals.vat : null);
    const { error: updErr } = await admin
      .from("purchases")
      .update({
        status: recordOnly ? "recorded" : "needs_review",
        error: null,
        supplier_id: supplierId,
        supplier_name: supplierName,
        invoice_number: doc.invoice_number,
        receipt_date: doc.invoice_date,
        currency: doc.currency ?? "EUR",
        total_amount: gross ?? (doc.prices_include_vat ? linesSum : null),
        net_amount: doc.totals.net ?? (doc.prices_include_vat === false ? linesSum : null),
        vat_amount: doc.totals.vat,
        analysis: { document: doc, warnings, supplier_match: supplierMatch, ms, attempts },
        analysis_model: model,
        updated_at: new Date().toISOString(),
      })
      .eq("id", purchaseId);
    if (updErr) throw new Error(updErr.message);

    const matched = items.filter((i) => i.material_id).length;
    console.log(
      `[scan-expense] ${purchaseId}: ${supplierName ?? "?"} #${doc.invoice_number ?? "?"}, ${items.length} lines, ` +
        `${matched} matched, supplier ${supplierMatch.status}, ${model} ${ms}ms`
    );
    // History imports stay quiet; a real scan is announced on the admin phones.
    if (!recordOnly) {
      const total = gross ?? (doc.prices_include_vat ? linesSum : null);
      const body = [
        warnings.some((w) => w.code === "duplicate") ? "Already scanned before!" : null,
        doc.invoice_number ? `No. ${doc.invoice_number}` : null,
        total !== null ? money(total) : null,
        `${items.length} ${items.length === 1 ? "item" : "items"}, ${matched} matched`,
      ].filter(Boolean).join(" · ") + (supplierId ? ". Tap to review." : ". Choose the supplier, then book.");
      await notifyScan(admin, supplierId ? `Invoice read: ${supplierName}` : "Invoice read: new supplier?", body, purchaseId);
    }
    return { purchase_id: purchaseId, status: recordOnly ? "recorded" : "needs_review" };
  } catch (e) {
    const message = (e as Error).message ?? String(e);
    const extractError = e instanceof ExtractError ? e : null;
    console.error(`[scan-expense] ${purchaseId} failed:`, message, extractError?.details ?? "");
    await admin
      .from("purchases")
      .update({
        status: "failed",
        error: message.slice(0, 1000),
        analysis: extractError ? { attempts: extractError.attempts, details: extractError.details } : null,
        updated_at: new Date().toISOString(),
      })
      .eq("id", purchaseId);
    if (!recordOnly) await notifyScan(admin, "Invoice could not be read", message, purchaseId);
    return { purchase_id: purchaseId, status: "failed", error: message };
  }
}

export type { ExtractedDocument };

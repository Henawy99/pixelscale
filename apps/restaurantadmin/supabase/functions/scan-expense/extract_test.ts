// Run: deno test supabase/functions/scan-expense/extract_test.ts
import { assertEquals, assertRejects } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import { extractDocument, ExtractError } from "./extract.ts";

const files = [{ mimeType: "image/jpeg", base64: "" }];
const answer = {
  candidates: [{ content: { parts: [{ text: JSON.stringify({ document_type: "invoice", invoice_number: "106808", lines: [] }) }] } }],
};

/** Fakes Gemini: each model answers with the given HTTP status (200 = a document). */
function fakeGemini(statusByModel: Record<string, number>, calls: string[]) {
  const real = globalThis.fetch;
  globalThis.fetch = ((input: string | URL | Request) => {
    const model = String(input).match(/models\/([^:]+):/)![1];
    calls.push(model);
    const status = statusByModel[model] ?? 404;
    return Promise.resolve(
      status === 200 ? new Response(JSON.stringify(answer)) : new Response("{}", { status }),
    );
  }) as typeof fetch;
  return () => (globalThis.fetch = real);
}

Deno.test("a busy model is skipped at once and the next one reads the invoice", async () => {
  const calls: string[] = [];
  const restore = fakeGemini({ a: 503, b: 503, c: 200 }, calls);
  try {
    const r = await extractDocument(files, [], [], "key", ["a", "b", "c"]);
    assertEquals(r.model, "c");
    assertEquals(r.doc.invoice_number, "106808");
    assertEquals(calls, ["a", "b", "c"]);
    assertEquals(r.attempts.map((a) => a.status), [503, 503, 200]);
  } finally {
    restore();
  }
});

Deno.test("busy models get a second round; a rejected key does not", async () => {
  const calls: string[] = [];
  const restore = fakeGemini({ a: 503, b: 403 }, calls);
  try {
    const err = await assertRejects(() => extractDocument(files, [], [], "key", ["a", "b"]), ExtractError);
    assertEquals(calls, ["a", "b", "a"]);
    assertEquals((err as ExtractError).message.startsWith("Gemini is very busy"), true);
  } finally {
    restore();
  }
});

Deno.test("no new call is started once the time budget is used up", async () => {
  const calls: string[] = [];
  const restore = fakeGemini({ a: 200 }, calls);
  try {
    await assertRejects(() => extractDocument(files, [], [], "key", ["a"], Date.now() + 5_000), ExtractError);
    assertEquals(calls, []);
  } finally {
    restore();
  }
});

Deno.test("a key rejected by every model is reported as such", async () => {
  const restore = fakeGemini({ a: 403, b: 403 }, []);
  try {
    const err = await assertRejects(() => extractDocument(files, [], [], "key", ["a", "b"]), ExtractError);
    assertEquals((err as ExtractError).message.startsWith("The Gemini key on the server was rejected"), true);
  } finally {
    restore();
  }
});

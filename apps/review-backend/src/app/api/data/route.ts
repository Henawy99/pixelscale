import { timingSafeEqual } from 'node:crypto';
import { NextRequest, NextResponse } from 'next/server';
import { db } from '@/lib/db';

export const dynamic = 'force-dynamic';

const KEY_PREFIX = '@pixelreview_';
const MAX_VALUE_LENGTH = 5_000_000;

interface DataRow {
  key: string;
  value: string;
  updated_at: string;
}

/** Only the review app knows the token (APP_DATA_TOKEN), so driver phone numbers and payouts stay private. */
function authorized(req: NextRequest): boolean {
  const expected = process.env.APP_DATA_TOKEN;
  const given = req.headers.get('x-app-token');
  if (!expected || !given) return false;
  const a = Buffer.from(given);
  const b = Buffer.from(expected);
  return a.length === b.length && timingSafeEqual(a, b);
}

const unauthorized = () => NextResponse.json({ success: false, error: 'Not authorized' }, { status: 401 });

function failure(err: unknown) {
  const error = err instanceof Error ? err.message : 'Database error';
  console.error('API Error in /api/data:', error);
  return NextResponse.json({ success: false, error }, { status: 500 });
}

/** Every saved key with its value and when it last changed. */
export async function GET(req: NextRequest) {
  if (!authorized(req)) return unauthorized();
  try {
    const sql = await db();
    const rows = (await sql`SELECT key, value, updated_at FROM app_data`) as DataRow[];
    const items = Object.fromEntries(rows.map((r) => [r.key, { value: r.value, updatedAt: r.updated_at }]));
    return NextResponse.json({ success: true, items });
  } catch (err) {
    return failure(err);
  }
}

/** Saves `{ items: [{ key, value }] }` in one transaction; `value: null` deletes the key. */
export async function PUT(req: NextRequest) {
  if (!authorized(req)) return unauthorized();
  const body = await req.json().catch(() => null);
  const items: unknown = body?.items;
  if (!Array.isArray(items) || items.length === 0) {
    return NextResponse.json({ success: false, error: 'Expected { items: [{ key, value }] }' }, { status: 400 });
  }
  for (const item of items) {
    const valid =
      typeof item?.key === 'string' &&
      item.key.startsWith(KEY_PREFIX) &&
      item.key.length <= 200 &&
      (item.value === null || (typeof item.value === 'string' && item.value.length <= MAX_VALUE_LENGTH));
    if (!valid) {
      return NextResponse.json({ success: false, error: `Invalid item: ${String(item?.key)}` }, { status: 400 });
    }
  }

  try {
    const sql = await db();
    await sql.transaction(
      (items as { key: string; value: string | null }[]).map(({ key, value }) =>
        value === null
          ? sql`DELETE FROM app_data WHERE key = ${key}`
          : sql`
              INSERT INTO app_data (key, value, updated_at) VALUES (${key}, ${value}, now())
              ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value, updated_at = now()`
      )
    );
    return NextResponse.json({ success: true, saved: items.length });
  } catch (err) {
    return failure(err);
  }
}

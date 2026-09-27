import { neon } from '@neondatabase/serverless';

/**
 * The review app's saved data (drivers, review people, assignments, tour catalog, done bookings,
 * generated reviews) lives in one Neon Postgres table, one row per app storage key. Values are the
 * app's JSON strings, stored as-is so the app gets back exactly what it wrote.
 */

let client: ReturnType<typeof neon> | null = null;
let schemaReady: Promise<void> | null = null;

function sql() {
  const url = process.env.DATABASE_URL;
  if (!url) throw new Error('DATABASE_URL is not configured');
  client ??= neon(url);
  return client;
}

/** Creates the table on first use, so a fresh database needs no manual setup. */
export async function db() {
  const q = sql();
  schemaReady ??= q`
    CREATE TABLE IF NOT EXISTS app_data (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )`.then(() => undefined);
  try {
    await schemaReady;
  } catch (err) {
    schemaReady = null;
    throw err;
  }
  return q;
}

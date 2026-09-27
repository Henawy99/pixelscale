import Storage from 'expo-sqlite/kv-store';
import { DEFAULT_API_URL, STORAGE_KEY_API_URL } from './apiConfig';

/**
 * Keeps the app's data in the backend's Postgres database (/api/data), so a reinstall, a new phone or
 * Expo Go all see the same drivers, review people and assignments. The phone's SQLite store stays the
 * working copy: reads never wait for the network, writes are uploaded right after they happen, and
 * anything written offline is queued until the next successful upload.
 *
 * Mail passwords, API keys and the server address are not in this list and stay on the phone.
 */
const CLOUD_KEYS = [
  '@pixelreview_drivers',
  '@pixelreview_driver_assignments',
  '@pixelreview_reviewers',
  '@pixelreview_reviewer_assignments',
  '@pixelreview_tour_catalog_v2',
  '@pixelreview_booking_tour_links',
  '@pixelreview_done_bookings',
  '@pixelreview_history',
] as const;

/** Set once this install has merged its data with the database. */
const MERGED_FLAG = '@pixelreview_cloud_merged_v1';
/** Keys changed on this phone that the database doesn't have yet. */
const PENDING_KEY = '@pixelreview_cloud_pending';
const LAST_SYNC_KEY = '@pixelreview_cloud_last_sync';

const TOKEN = process.env.EXPO_PUBLIC_APP_DATA_TOKEN ?? '';

// Development runs (Expo Go, simulators) keep their own copy in the database, so testing never
// touches the real drivers and review people.
const LOCAL_PREFIX = '@pixelreview_';
const REMOTE_PREFIX = __DEV__ ? '@pixelreview_dev_' : LOCAL_PREFIX;
const remoteKey = (key: string) => REMOTE_PREFIX + key.slice(LOCAL_PREFIX.length);
const STARTUP_TIMEOUT_MS = 5000;
const REQUEST_TIMEOUT_MS = 15000;

export function isCloudKey(key: string): boolean {
  return (CLOUD_KEYS as readonly string[]).includes(key);
}

export interface CloudStatus {
  /** False when the app was built without the database token. */
  enabled: boolean;
  lastSyncedAt: number | null;
  pendingChanges: number;
  error: string | null;
}

let pending = new Set<string>();
let status: CloudStatus = { enabled: TOKEN.length > 0, lastSyncedAt: null, pendingChanges: 0, error: null };
const listeners = new Set<(s: CloudStatus) => void>();

function setStatus(patch: Partial<CloudStatus>) {
  status = { ...status, ...patch, pendingChanges: pending.size };
  listeners.forEach((l) => l(status));
}

export function getCloudStatus(): CloudStatus {
  return status;
}

export function subscribeCloudStatus(listener: (s: CloudStatus) => void): () => void {
  listeners.add(listener);
  return () => {
    listeners.delete(listener);
  };
}

async function request(method: 'GET' | 'PUT', body?: unknown, timeoutMs = REQUEST_TIMEOUT_MS) {
  const base = ((await Storage.getItem(STORAGE_KEY_API_URL))?.trim() || DEFAULT_API_URL).replace(/\/$/, '');
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(`${base}/api/data`, {
      method,
      headers: { 'Content-Type': 'application/json', Accept: 'application/json', 'x-app-token': TOKEN },
      body: body === undefined ? undefined : JSON.stringify(body),
      signal: controller.signal,
    });
    const data = await res.json().catch(() => null);
    if (!res.ok || !data?.success) throw new Error(data?.error || `Database returned HTTP ${res.status}`);
    return data;
  } catch (err) {
    if (controller.signal.aborted) throw new Error('The database did not answer in time.');
    throw err;
  } finally {
    clearTimeout(timer);
  }
}

async function savePending() {
  await Storage.setItem(PENDING_KEY, JSON.stringify([...pending]));
  setStatus({});
}

function isPlainObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null && !Array.isArray(v);
}

/**
 * Combines this phone's value with the database's the first time they meet, so nothing is lost on
 * either side: lists are joined by `id` and records by key, with the database winning on conflicts.
 */
function mergeValues(local: string, cloud: string): string {
  try {
    const l: unknown = JSON.parse(local);
    const c: unknown = JSON.parse(cloud);
    if (Array.isArray(l) && Array.isArray(c)) {
      const ids = new Set(c.map((item) => (isPlainObject(item) ? item.id : undefined)));
      const extra = l.filter((item) => isPlainObject(item) && typeof item.id === 'string' && !ids.has(item.id));
      return extra.length ? JSON.stringify([...c, ...extra]) : cloud;
    }
    if (isPlainObject(l) && isPlainObject(c)) {
      const added = Object.keys(l).filter((k) => !(k in c));
      return added.length ? JSON.stringify({ ...l, ...c }) : cloud;
    }
  } catch {
    // Not JSON: the database copy wins.
  }
  return cloud;
}

/**
 * Pulls the database into the phone's store. Returns true when local data changed, so screens reload.
 * Before this install's first merge, both sides are combined; after it, the database wins unless the
 * phone has an unsent change for that key.
 */
async function pull(timeoutMs?: number): Promise<boolean> {
  const data = await request('GET', undefined, timeoutMs);
  const items: Record<string, { value: string }> = data.items ?? {};
  const firstMerge = !(await Storage.getItem(MERGED_FLAG));
  let changed = false;

  for (const key of CLOUD_KEYS) {
    const cloud = items[remoteKey(key)]?.value ?? null;
    const local = await Storage.getItem(key);
    if (firstMerge) {
      if (cloud === null) {
        if (local !== null) pending.add(key);
        continue;
      }
      const merged = local === null ? cloud : mergeValues(local, cloud);
      if (merged !== local) {
        await Storage.setItem(key, merged);
        changed = true;
      }
      if (merged !== cloud) pending.add(key);
      else pending.delete(key);
    } else if (cloud !== null && cloud !== local && !pending.has(key)) {
      // Re-checked after the awaits above: an edit made during the pull must not be overwritten.
      await Storage.setItem(key, cloud);
      changed = true;
    }
  }

  if (firstMerge) await Storage.setItem(MERGED_FLAG, String(Date.now()));
  await savePending();
  return changed;
}

let flushing: Promise<void> | null = null;
let flushTimer: ReturnType<typeof setTimeout> | null = null;

/** Uploads every queued change in one request. Keys edited again mid-upload stay queued. */
async function flush(): Promise<void> {
  if (!status.enabled || pending.size === 0 || !(await Storage.getItem(MERGED_FLAG))) return;
  if (flushing) return flushing;
  flushing = (async () => {
    const batch = await Promise.all([...pending].map(async (key) => ({ key, value: await Storage.getItem(key) })));
    await request('PUT', { items: batch.map(({ key, value }) => ({ key: remoteKey(key), value })) });
    for (const { key, value } of batch) {
      if ((await Storage.getItem(key)) === value) pending.delete(key);
    }
    await savePending();
    await markSynced();
  })();
  try {
    await flushing;
  } catch (err) {
    setStatus({ error: err instanceof Error ? err.message : 'Upload failed' });
  } finally {
    flushing = null;
  }
}

async function markSynced() {
  const now = Date.now();
  await Storage.setItem(LAST_SYNC_KEY, String(now));
  setStatus({ lastSyncedAt: now, error: null });
}

/** Called by the storage layer after every write, so changes reach the database within a second. */
export function noteLocalWrite(key: string): void {
  if (!status.enabled || !isCloudKey(key)) return;
  pending.add(key);
  savePending().catch(() => {});
  if (flushTimer) clearTimeout(flushTimer);
  flushTimer = setTimeout(() => {
    flushTimer = null;
    flush();
  }, 500);
}

/**
 * Runs once before the app's first read: loads the queue and pulls the database (briefly, so an
 * offline start still opens with the phone's copy), then uploads anything queued.
 */
export async function startCloudSync(): Promise<void> {
  try {
    pending = new Set(JSON.parse((await Storage.getItem(PENDING_KEY)) || '[]'));
  } catch {
    pending = new Set();
  }
  const last = Number(await Storage.getItem(LAST_SYNC_KEY));
  setStatus({ lastSyncedAt: last > 0 ? last : null });
  if (!status.enabled) return;
  try {
    await pull(STARTUP_TIMEOUT_MS);
    await markSynced();
  } catch (err) {
    setStatus({ error: err instanceof Error ? err.message : 'Could not reach the database' });
  }
  flush();
}

/** Uploads queued changes, then pulls edits made elsewhere. Resolves true when local data changed. */
export async function syncWithCloud(): Promise<boolean> {
  if (!status.enabled) return false;
  try {
    await flush();
    const changed = await pull();
    await markSynced();
    await flush();
    return changed;
  } catch (err) {
    setStatus({ error: err instanceof Error ? err.message : 'Could not reach the database' });
    return false;
  }
}

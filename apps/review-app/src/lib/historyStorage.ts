import { kv } from './storage';
import { AnalyzeResponse, HistoryItem } from '../types';

const STORAGE_KEY_HISTORY = '@pixelreview_history';

export async function getStoredHistory(): Promise<HistoryItem[]> {
  try {
    const raw = await kv.getItem(STORAGE_KEY_HISTORY);
    const parsed = raw ? JSON.parse(raw) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

async function writeHistory(items: HistoryItem[]): Promise<HistoryItem[]> {
  await kv.setItem(STORAGE_KEY_HISTORY, JSON.stringify(items));
  return items;
}

/** Saves a generated review to history. Returns null when the response has nothing to save. */
export async function addHistoryItem(res: AnalyzeResponse): Promise<HistoryItem | null> {
  if (!res.review || !res.tour) return null;
  const item: HistoryItem = {
    id: String(Date.now()),
    timestamp: Date.now(),
    tour: res.tour,
    review: res.review,
    photos: res.photos || [],
  };
  const current = await getStoredHistory();
  await writeHistory([item, ...current]);
  return item;
}

export async function deleteHistoryItem(id: string): Promise<HistoryItem[]> {
  const current = await getStoredHistory();
  return writeHistory(current.filter((h) => h.id !== id));
}

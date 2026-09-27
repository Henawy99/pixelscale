import Storage from 'expo-sqlite/kv-store';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { noteLocalWrite, startCloudSync } from './cloudSync';

const MIGRATION_FLAG = '@pixelreview_kv_migrated_v1';

let readyPromise: Promise<void> | null = null;

/**
 * Runs before the first read or write: a one-time copy of every `@pixelreview_*` key from the old
 * AsyncStorage backend into the expo-sqlite key-value store, then a pull from the cloud database so
 * the app opens with the saved drivers, review people and assignments. Safe to call repeatedly.
 */
export function ensureStorageReady(): Promise<void> {
  if (!readyPromise) {
    readyPromise = (async () => {
      await migrateFromAsyncStorage();
      await startCloudSync();
    })();
  }
  return readyPromise;
}

async function migrateFromAsyncStorage(): Promise<void> {
  if (await Storage.getItem(MIGRATION_FLAG)) return;
  try {
    const keys = (await AsyncStorage.getAllKeys()).filter((k) => k.startsWith('@pixelreview_'));
    if (keys.length > 0) {
      const pairs = await AsyncStorage.multiGet(keys);
      const present = pairs.filter((pair): pair is [string, string] => pair[1] !== null);
      if (present.length > 0) await Storage.multiSet(present);
    }
  } catch (err) {
    console.warn('AsyncStorage migration skipped:', err);
  }
  await Storage.setItem(MIGRATION_FLAG, String(Date.now()));
}

/** Key-value store used by the whole app (AsyncStorage-compatible subset). */
export const kv = {
  async getItem(key: string): Promise<string | null> {
    await ensureStorageReady();
    return Storage.getItem(key);
  },
  async setItem(key: string, value: string): Promise<void> {
    await ensureStorageReady();
    await Storage.setItem(key, value);
    noteLocalWrite(key);
  },
  async removeItem(key: string): Promise<void> {
    await ensureStorageReady();
    await Storage.removeItem(key);
    noteLocalWrite(key);
  },
};

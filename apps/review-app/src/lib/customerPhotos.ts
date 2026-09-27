import { Directory, File, Paths } from 'expo-file-system';

/**
 * Photos taken of a booking's guests, copied from the gallery into Documents/customer-photos/<ref>/ so
 * they survive until they are sent. The folder is the source of truth; nothing is kept in kv, because
 * absolute file URIs change when iOS moves the app container on updates.
 */
const ROOT = 'customer-photos';
/** Copies are removed this long after a booking is marked done; the originals stay in the gallery. */
const KEEP_AFTER_DONE_MS = 14 * 24 * 60 * 60 * 1000;

const folderName = (ref: string) => ref.replace(/[^A-Za-z0-9_-]/g, '_');
const folderFor = (ref: string) => new Directory(Paths.document, ROOT, folderName(ref));

/** File URIs in the order the photos were added. */
export function listCustomerPhotos(ref: string): string[] {
  const folder = folderFor(ref);
  if (!folder.exists) return [];
  return folder
    .list()
    .filter((entry): entry is File => entry instanceof File)
    .map((file) => file.uri)
    .sort();
}

/** Copies picked photos into the booking's folder and returns the full list. */
export async function addCustomerPhotos(ref: string, sourceUris: string[]): Promise<string[]> {
  const folder = folderFor(ref);
  folder.create({ intermediates: true, idempotent: true });
  const stamp = Date.now();
  await Promise.all(
    sourceUris.map((uri, i) => {
      const ext = uri.split('?')[0].split('.').pop()?.toLowerCase() || 'jpg';
      // Timestamp + index keeps names unique and sorted in pick order.
      const name = `${stamp}-${String(i).padStart(3, '0')}.${ext}`;
      return new File(uri).copy(new File(folder, name));
    })
  );
  return listCustomerPhotos(ref);
}

export function removeCustomerPhoto(ref: string, uri: string): string[] {
  const file = new File(uri);
  if (file.exists) file.delete();
  return listCustomerPhotos(ref);
}

/** Deletes the copies for bookings that were marked done more than two weeks ago. */
export function pruneCustomerPhotos(doneAt: Record<string, number>): void {
  const root = new Directory(Paths.document, ROOT);
  if (!root.exists) return;
  const cutoff = Date.now() - KEEP_AFTER_DONE_MS;
  const expired = new Set(
    Object.entries(doneAt)
      .filter(([, at]) => at < cutoff)
      .map(([ref]) => folderName(ref))
  );
  for (const entry of root.list()) {
    if (entry instanceof Directory && expired.has(entry.name)) entry.delete();
  }
}

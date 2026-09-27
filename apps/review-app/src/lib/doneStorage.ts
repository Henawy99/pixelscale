import { kv } from './storage';

/** Booking reference → when it was marked done (ms). */
export const STORAGE_KEY_DONE_BOOKINGS = '@pixelreview_done_bookings';

export async function getStoredDoneBookings(): Promise<Record<string, number>> {
  try {
    const raw = await kv.getItem(STORAGE_KEY_DONE_BOOKINGS);
    const parsed = raw ? JSON.parse(raw) : {};
    return typeof parsed === 'object' && parsed !== null ? parsed : {};
  } catch (err) {
    console.warn('Error reading done bookings:', err);
    return {};
  }
}

export async function setStoredBookingDone(bookingRef: string, done: boolean): Promise<Record<string, number>> {
  const current = await getStoredDoneBookings();
  if (done) current[bookingRef] = Date.now();
  else delete current[bookingRef];
  await kv.setItem(STORAGE_KEY_DONE_BOOKINGS, JSON.stringify(current));
  return current;
}

import { BookingItem } from '../types';

const DAY_MS = 86_400_000;

/** Local calendar key, e.g. "2026-09-27". */
export function toDateKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

export function fromDateKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
}

export function startOfDay(d: Date): Date {
  const out = new Date(d);
  out.setHours(0, 0, 0, 0);
  return out;
}

/** Monday of the week containing `d`. */
export function startOfWeek(d: Date): Date {
  const out = startOfDay(d);
  const day = out.getDay();
  out.setDate(out.getDate() - (day === 0 ? 6 : day - 1));
  return out;
}

export function addDays(d: Date, days: number): Date {
  const out = new Date(d);
  out.setDate(out.getDate() + days);
  return out;
}

/** The tour date of a booking, or null when it can't be determined. */
export function bookingDate(b: BookingItem): Date | null {
  if (b.timestamp) return new Date(b.timestamp);
  if (b.date && b.date !== 'Upcoming') {
    const parsed = Date.parse(b.date.replace(/at /i, ''));
    if (!isNaN(parsed)) return new Date(parsed);
  }
  return null;
}

export function bookingDateKey(b: BookingItem): string | null {
  const d = bookingDate(b);
  return d ? toDateKey(d) : null;
}

/**
 * Start time as written in the booking email ("10:00 AM", "08:30"), falling back to the
 * timestamp. The email text is preferred because it is the operator's local time.
 */
export function bookingTime(b: BookingItem): string | null {
  const match = b.date?.match(/(\d{1,2}:\d{2}\s*(?:AM|PM)?)/i);
  if (match) return match[1].replace(/\s+/g, ' ').toUpperCase();
  if (b.timestamp) {
    return new Date(b.timestamp).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' });
  }
  return null;
}

/** "September 2026" — the month a booking's revenue belongs to. */
export function bookingMonthLabel(b: BookingItem): string {
  if (b.date && b.date !== 'Upcoming') {
    const match = b.date.match(/([A-Za-z]+)\s+\d{1,2},\s+(\d{4})/);
    if (match) return `${match[1]} ${match[2]}`;
  }
  if (b.timestamp) {
    return new Date(b.timestamp).toLocaleString('en-US', { month: 'long', year: 'numeric' });
  }
  return 'Other';
}

export function currentMonthLabel(): string {
  return new Date().toLocaleString('en-US', { month: 'long', year: 'numeric' });
}

export function weekdayShort(d: Date): string {
  return d.toLocaleDateString('en-US', { weekday: 'short' }).toUpperCase();
}

export function monthShort(d: Date): string {
  return d.toLocaleDateString('en-US', { month: 'short' }).toUpperCase();
}

export function formatLongDay(d: Date): string {
  return d.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
}

export function formatWeekRange(monday: Date): string {
  const sunday = addDays(monday, 6);
  const sameMonth = monday.getMonth() === sunday.getMonth();
  const start = monday.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
  const end = sunday.toLocaleDateString('en-US', sameMonth ? { day: 'numeric' } : { month: 'short', day: 'numeric' });
  return `${start} – ${end}`;
}

export function formatRelative(iso: string | number): string {
  const then = typeof iso === 'number' ? iso : Date.parse(iso);
  if (isNaN(then)) return '—';
  const diff = Date.now() - then;
  if (diff < 60_000) return 'Just now';
  if (diff < 3_600_000) return `${Math.floor(diff / 60_000)} min ago`;
  if (diff < DAY_MS) return `${Math.floor(diff / 3_600_000)} h ago`;
  return new Date(then).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

export interface BookingGroup<T> {
  key: string;
  title: string;
  items: T[];
}

/**
 * Buckets bookings for an agenda-style list: Today, Tomorrow, This Week, then one bucket per
 * month. Past bookings go into a single "Past" bucket (most recent first).
 */
export function groupBookingsByDate(bookings: BookingItem[], now = new Date()): {
  upcoming: BookingGroup<BookingItem>[];
  past: BookingItem[];
} {
  const today = startOfDay(now).getTime();
  const tomorrow = today + DAY_MS;
  const weekEnd = today + 7 * DAY_MS;

  const upcoming: BookingGroup<BookingItem>[] = [];
  const byKey = new Map<string, BookingGroup<BookingItem>>();
  const past: BookingItem[] = [];

  const push = (key: string, title: string, b: BookingItem) => {
    let group = byKey.get(key);
    if (!group) {
      group = { key, title, items: [] };
      byKey.set(key, group);
      upcoming.push(group);
    }
    group.items.push(b);
  };

  const sorted = [...bookings].sort((a, b) => (a.timestamp ?? 0) - (b.timestamp ?? 0));
  for (const b of sorted) {
    const d = bookingDate(b);
    const day = d ? startOfDay(d).getTime() : null;
    if (day === null) push('undated', 'Date unknown', b);
    else if (day < today) past.push(b);
    else if (day === today) push('today', 'Today', b);
    else if (day === tomorrow) push('tomorrow', 'Tomorrow', b);
    else if (day < weekEnd) push('week', 'Next 7 Days', b);
    else {
      const label = d!.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
      push(`m-${d!.getFullYear()}-${d!.getMonth()}`, label, b);
    }
  }

  past.reverse();
  return { upcoming, past };
}

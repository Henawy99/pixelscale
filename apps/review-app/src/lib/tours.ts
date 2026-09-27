import { BookingItem, OfferedTour, getNumericPrice, isBookingReview, platformFeeRate } from '../types';
import { NO_TOUR, parseGygUrl } from './toursStorage';
import { stopNames, tourContentFor } from './itinerary';

/**
 * Parses the total number of passengers / participants from GYG string.
 * Examples:
 * - "2 x Adults (Age 0 - 99)" -> 2
 * - "1 x Adult (Age 18 - 99)" -> 1
 * - "2 x Adult, 2 x Child" -> 4
 * - "3 Participants" -> 3
 */
export function parsePassengerCount(participantsText?: string): number {
  if (!participantsText) return 1;

  const text = participantsText.trim();

  // Pattern 1: Sum up all "N x ..." occurrences
  const multiplierRegex = /(\d+)\s*x/gi;
  let match: RegExpExecArray | null;
  let totalFromMultipliers = 0;

  while ((match = multiplierRegex.exec(text)) !== null) {
    const count = parseInt(match[1], 10);
    if (!isNaN(count) && count > 0) totalFromMultipliers += count;
  }
  if (totalFromMultipliers > 0) return totalFromMultipliers;

  // Pattern 2: "N Adult" or "N Participants" or "N Person"
  const wordMatch = text.match(/(\d+)\s*(?:adult|participant|person|child|guest|passenger|people|erwachsene)/i);
  if (wordMatch) {
    const count = parseInt(wordMatch[1], 10);
    if (!isNaN(count) && count > 0) return count;
  }

  // Pattern 3: Any standalone number
  const anyNumMatch = text.match(/\b(\d+)\b/);
  if (anyNumMatch) {
    const count = parseInt(anyNumMatch[1], 10);
    if (!isNaN(count) && count > 0) return count;
  }

  return 1;
}

// ─── Matching bookings to tours ─────────────────────────────────────────────

/** How a booking was tied to its tour, from most to least certain. */
export type TourMatchSource = 'manual' | 'reference' | 'title' | 'similar';

export interface TourMatch {
  tour: OfferedTour;
  via: TourMatchSource;
}

export type TourMatcher = (booking: BookingItem) => TourMatch | null;

/** Words too common across the catalog to tell tours apart. */
const STOPWORDS = new Set(['from', 'the', 'and', 'with', 'a', 'an', 'of', 'in', 'to', 'for', 'tour', 'trip', 'day', 'private']);
const SIMILAR_MIN_SCORE = 0.75;
const SIMILAR_MIN_LEAD = 0.1;

/** "From Salzburg: Hallstatt, 5 Fingers & Gosausee" and its URL slug both become "from salzburg hallstatt 5 fingers gosausee". */
export function normalizeTitle(title: string): string {
  let s = title.toLowerCase();
  try {
    s = s.normalize('NFKD').replace(/[̀-ͯ]/g, '');
  } catch {
    // Engines without normalize() keep the accents; exact matches still work.
  }
  return s
    .replace(/[^a-z0-9À-ɏ؀-ۿ]+/g, ' ')
    .split(' ')
    .filter((w) => w && w !== 'and')
    .join(' ');
}

function tokens(normalized: string): Set<string> {
  return new Set(normalized.split(' ').filter((w) => !STOPWORDS.has(w)));
}

function dice(a: Set<string>, b: Set<string>): number {
  if (a.size === 0 || b.size === 0) return 0;
  let shared = 0;
  a.forEach((w) => {
    if (b.has(w)) shared++;
  });
  return (2 * shared) / (a.size + b.size);
}

/** Every title a tour is known by: current title, older titles and its GetYourGuide URL slug. */
function titleKeys(tour: OfferedTour): string[] {
  const keys = [tour.title, ...(tour.aliases ?? [])];
  const slug = parseGygUrl(tour.gygUrl)?.slugTitle;
  if (slug) keys.push(slug);
  return keys.map(normalizeTitle).filter(Boolean);
}

/**
 * Builds a memoised booking → tour lookup. Order of trust: a choice made by hand, the product
 * reference code / GYG tour id when the booking carries one, an exact (normalised) title or alias,
 * then a clearly-best similar title.
 */
export function createTourMatcher(tours: OfferedTour[], links: Record<string, string>): TourMatcher {
  const byId = new Map(tours.map((t) => [t.id, t]));
  const byCode = new Map(
    tours.filter((t) => t.referenceCode).map((t) => [t.referenceCode!.trim().toLowerCase(), t])
  );
  const byGygId = new Map(tours.filter((t) => t.gygTourId).map((t) => [t.gygTourId!, t]));
  const byTitle = new Map<string, OfferedTour>();
  const tokenSets: { tour: OfferedTour; set: Set<string> }[] = [];
  tours.forEach((tour) => {
    titleKeys(tour).forEach((key) => {
      if (!byTitle.has(key)) byTitle.set(key, tour);
      tokenSets.push({ tour, set: tokens(key) });
    });
  });

  const cache = new Map<string, TourMatch | null>();

  const resolve = (b: BookingItem): TourMatch | null => {
    const linked = links[b.referenceNumber];
    if (linked === NO_TOUR) return null;
    const manual = linked ? byId.get(linked) : undefined;
    if (manual) return { tour: manual, via: 'manual' };

    const code = b.productReference?.trim().toLowerCase();
    const byRef = (code && byCode.get(code)) || (b.gygTourId && byGygId.get(b.gygTourId));
    if (byRef) return { tour: byRef, via: 'reference' };

    const title = normalizeTitle(b.tourTitle || '');
    if (!title) return null;
    const exact = byTitle.get(title);
    if (exact) return { tour: exact, via: 'title' };

    // Similar title: best score per tour, accepted only when it clearly beats the runner-up.
    const bookingTokens = tokens(title);
    const best = new Map<OfferedTour, number>();
    tokenSets.forEach(({ tour, set }) => {
      best.set(tour, Math.max(best.get(tour) ?? 0, dice(bookingTokens, set)));
    });
    const ranked = [...best.entries()].sort((x, y) => y[1] - x[1]);
    const [first, second] = ranked;
    if (first && first[1] >= SIMILAR_MIN_SCORE && first[1] - (second?.[1] ?? 0) >= SIMILAR_MIN_LEAD) {
      return { tour: first[0], via: 'similar' };
    }
    return null;
  };

  return (b) => {
    const key = `${b.referenceNumber}|${b.tourTitle}|${b.productReference ?? ''}`;
    if (!cache.has(key)) cache.set(key, resolve(b));
    return cache.get(key)!;
  };
}

/** "Hallstatt funicular, Skywalk & Salt Mine, Eagle’s Nest bus & elevator" — for review notes and summaries. */
export function includedTicketsText(tour: OfferedTour): string {
  return (tour.tickets ?? []).map((t) => t.name).join(', ');
}

/** Studio notes that tell the review writer which tour it is and what was included. */
export function reviewNotesFor(tour: OfferedTour, extra?: string): string {
  const tickets = includedTicketsText(tour);
  const content = tourContentFor(tour);
  return [
    `Tour: ${tour.title}`,
    content ? `Stops: ${stopNames(content)}` : null,
    tickets ? `Tickets included: ${tickets}` : null,
    extra || null,
  ]
    .filter(Boolean)
    .join('\n');
}

// ─── Ticket costs ────────────────────────────────────────────────────────────

export interface TicketLine {
  name: string;
  pricePerPassenger: number;
  subtotal: number;
}

export interface TicketDeductionResult {
  tour: OfferedTour | null;
  hasDeduction: boolean;
  totalCost: number;
  passengerCount: number;
  costPerPassenger: number;
  lines: TicketLine[];
  /** Tickets the tour includes that have no price yet, so the deduction is incomplete. */
  missingPrices: number;
  breakdownText: string;
  grossPrice: number;
  netGygPayout: number; // gross minus platform fee (30% GYG / 20% Airbnb)
  netProfitAfterTickets: number; // net payout minus ticket costs
}

/**
 * Tickets bought for a booking: guests × the per-guest price of every ticket its tour includes.
 * Cancelled and review bookings never buy tickets.
 */
export function getBookingTicketDeduction(booking: BookingItem, matchTour: TourMatcher): TicketDeductionResult {
  const gross = getNumericPrice(booking);
  const netGyg = parseFloat((gross * (1 - platformFeeRate(booking))).toFixed(2));
  const tour = matchTour(booking)?.tour ?? null;
  const base = {
    tour,
    hasDeduction: false,
    totalCost: 0,
    passengerCount: 0,
    costPerPassenger: 0,
    lines: [],
    missingPrices: 0,
    grossPrice: gross,
  };

  if (booking.status === 'cancelled') {
    return { ...base, breakdownText: 'Cancelled (No tickets)', netGygPayout: 0, netProfitAfterTickets: 0 };
  }
  if (isBookingReview(booking)) {
    return { ...base, breakdownText: 'Review Booking (No tickets)', netGygPayout: netGyg, netProfitAfterTickets: netGyg };
  }

  const passengers = parsePassengerCount(booking.participants);
  const tickets = tour?.tickets ?? [];
  const priced = tickets.filter((t) => t.pricePerPassenger > 0);
  const lines = priced.map((t) => ({
    name: t.name,
    pricePerPassenger: t.pricePerPassenger,
    subtotal: parseFloat((passengers * t.pricePerPassenger).toFixed(2)),
  }));
  const costPerPassenger = priced.reduce((sum, t) => sum + t.pricePerPassenger, 0);
  const totalCost = parseFloat((passengers * costPerPassenger).toFixed(2));

  return {
    ...base,
    hasDeduction: totalCost > 0,
    totalCost,
    passengerCount: passengers,
    costPerPassenger,
    lines,
    missingPrices: tickets.length - priced.length,
    breakdownText: !tour
      ? 'Tour not recognised'
      : tickets.length === 0
        ? 'No tickets included'
        : `${passengers} × €${costPerPassenger.toFixed(2)}`,
    netGygPayout: netGyg,
    netProfitAfterTickets: parseFloat((netGyg - totalCost).toFixed(2)),
  };
}

import { kv } from './storage';
import { OfferedTour, TourTicket } from '../types';

const STORAGE_KEY_TOURS = '@pixelreview_tour_catalog_v2';
const STORAGE_KEY_BOOKING_LINKS = '@pixelreview_booking_tour_links';

// Pre-catalog storage, read once to carry the user's own tours and ticket prices over.
const LEGACY_TOURS_KEY = '@pixelreview_offered_tours';
const LEGACY_RULES_KEY = '@pixelreview_ticket_rules';
const LEGACY_SAMPLE_TOUR_IDS = new Set(['tour_hallstatt_salt_mine', 'tour_salzburg_eagles_nest', 'tour_sound_of_music']);

const EAGLES_NEST_TICKET = 'Eagle’s Nest bus & elevator';

function seed(
  referenceCode: string,
  title: string,
  gygUrl: string,
  location: string,
  tickets: [name: string, price: number][] = [],
  aliases: string[] = []
): OfferedTour {
  const gygTourId = parseGygUrl(gygUrl)?.tourId;
  return {
    id: `gyg_${gygTourId ?? referenceCode}`,
    referenceCode,
    gygTourId,
    title,
    gygUrl,
    location,
    aliases,
    tickets: tickets.map(([name, pricePerPassenger], i) => ({
      id: `tkt_${gygTourId ?? referenceCode}_${i}`,
      name,
      pricePerPassenger,
    })),
    createdAt: 0,
  };
}

/**
 * The bookable products in the GetYourGuide Supplier Portal (September 2026), with the
 * tickets each product's inclusions promise. Prices of 0 still need to be filled in.
 */
export const SEED_TOURS: OfferedTour[] = [
  seed('LINZ-HALL-EAGLE', 'From Linz: Hallstatt & Eagle’s Nest Private Day Trip',
    'https://www.getyourguide.com/linz-l3463/from-linz-hallstatt-eagle-s-nest-private-day-trip-t1487987/',
    'Linz', [[EAGLES_NEST_TICKET, 32]]),
  seed('LINZ-HALL-LAKES', 'From Linz: Hallstatt, Traunsee & Gosausee Private Day Trip',
    'https://www.getyourguide.com/linz-l3463/from-linz-hallstatt-traunsee-gosausee-private-day-trip-t1487990/',
    'Linz'),
  seed('HALL-IMPERIAL', 'From Salzburg: Hallstatt, Bad Ischl & St. Wolfgang Tour',
    'https://www.getyourguide.com/salzburg-l4/from-salzburg-hallstatt-bad-ischl-st-wolfgang-tour-t1478630/',
    'Salzburg'),
  seed('HALL-5F-GOSAU', 'From Salzburg: Hallstatt, 5 Fingers & Gosausee Private Tour',
    'https://www.getyourguide.com/gmunden-l142086/from-salzburg-hallstatt-5-fingers-gosausee-day-trip-t1488651/',
    'Salzburg', [['Dachstein Krippenstein cable car (5 Fingers)', 0]]),
  seed('HALL-HISTORY', 'From Salzburg: Hallstatt Heritage & Eagle’s Nest Tour',
    'https://www.getyourguide.com/berchtesgaden-l94260/from-salzburg-hallstatt-heritage-eagle-s-nest-tour-t1468371/',
    'Salzburg', [[EAGLES_NEST_TICKET, 32]]),
  seed('HALL-SKYWALK-MOND', 'From Salzburg: Hallstatt Skywalk & Mondsee Private Tour',
    'https://www.getyourguide.com/hallstatt-l32535/from-salzburg-hallstatt-skywalk-mondsee-private-day-trip-t1488644/',
    'Salzburg', [['Hallstatt funicular & Skywalk', 0]]),
  seed('eagle-wwii-arabic', 'From Salzburg: Multilingual Eagle’s Nest WWII Tour',
    'https://www.getyourguide.com/salzburg-l4/from-salzburg-multilingual-eagle-s-nest-wwii-tour-t1486803/',
    'Salzburg', [[EAGLES_NEST_TICKET, 32], ['Documentation Obersalzberg', 0]]),
  seed('hallstatt-guided', 'Salzburg: Hallstatt & Alpine Lakes Private Day Trip',
    'https://www.getyourguide.com/salzburg-l4/salzburg-hallstatt-alpine-lakes-private-guided-tour-t1477374/',
    'Salzburg', [], ['Salzburg: Hallstatt & Alpine Lakes Private Guided Tour']),
  seed('T-1486364', 'From Salzburg: Private Swarovski, Innsbruck & Nordkette Tour',
    'https://www.getyourguide.com/salzburg-l4/from-salzburg-private-swarovski-innsbruck-nordkette-tour-t1486364/',
    'Salzburg', [['Swarovski Crystal Worlds', 0], ['Nordkette funicular & cable car', 0]]),
  seed('HALL-RB-ATTERSEE', 'From Salzburg: Hallstatt, Red Bull HQ & Attersee Day Trip',
    'https://www.getyourguide.com/hallstatt-l32535/from-salzburg-hallstatt-red-bull-hq-attersee-day-trip-t1488628/',
    'Salzburg'),
  seed('MUC-SALZ-HALL', 'From Munich: Salzburg, Hallstatt & Lakes Private Day Trip',
    'https://www.getyourguide.com/munich-l26/from-munich-salzburg-hallstatt-lakes-private-day-trip-t1482249/',
    'Munich'),
  seed('T-1478631', 'From Salzburg: Hallstatt Salt Mine & Skywalk Private Tour',
    'https://www.getyourguide.com/salzburg-l4/from-salzburg-hallstatt-salt-mine-skywalk-private-tour-t1478631/',
    'Salzburg', [['Hallstatt funicular, Skywalk & Salt Mine', 49]]),
  seed('TG1', 'Salzburg: Private Hallstatt & St. Gilgen Trip',
    'https://www.getyourguide.com/salzburg-l4/salzburg-private-hallstatt-half-day-tour-with-pickup-t1467727/',
    'Salzburg', [], ['Salzburg: 6-Hour Private Hallstatt & St. Gilgen Trip']),
  seed('zell-kitzsteinhorn', 'Salzburg: Zell am See & Kitzsteinhorn Private Trip',
    'https://www.getyourguide.com/zell-am-see-l104073/salzburg-zell-am-see-kitzsteinhorn-private-trip-t1468375/',
    'Salzburg', [['TOP OF SALZBURG cable car', 0]]),
];

/**
 * Reads a GetYourGuide product link, e.g.
 * https://www.getyourguide.com/salzburg-l4/from-salzburg-hallstatt-salt-mine-skywalk-private-tour-t1478631/?preview=…
 * → clean public URL, tour id "1478631", slug title and location "Salzburg".
 */
export function parseGygUrl(raw: string): { url: string; tourId: string; slugTitle: string; location?: string } | null {
  const match = raw
    .trim()
    .match(/^(?:https?:\/\/)?(?:[a-z]+\.)?getyourguide\.[a-z.]+\/(?:([a-z0-9-]+-l\d+)\/)?([a-z0-9-]+)-t(\d+)/i);
  if (!match) return null;
  const [, locSegment, titleSlug, tourId] = match;
  const words = (slug: string) =>
    slug
      .split('-')
      .filter(Boolean)
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
      .join(' ');
  return {
    url: `https://www.getyourguide.com/${locSegment ? `${locSegment.toLowerCase()}/` : ''}${titleSlug.toLowerCase()}-t${tourId}/`,
    tourId,
    slugTitle: words(titleSlug),
    location: locSegment ? words(locSegment.replace(/-l\d+$/i, '')) : undefined,
  };
}

function cloneSeed(): OfferedTour[] {
  return SEED_TOURS.map((t) => ({ ...t, aliases: [...(t.aliases ?? [])], tickets: (t.tickets ?? []).map((k) => ({ ...k })) }));
}

async function readJson<T>(key: string): Promise<T | null> {
  try {
    const raw = await kv.getItem(key);
    return raw ? (JSON.parse(raw) as T) : null;
  } catch {
    return null;
  }
}

interface LegacyRule {
  tourKeyword?: string;
  ticketCostPerPassenger?: number;
  isEnabled?: boolean;
}

interface LegacyTour extends OfferedTour {
  ticketCostPerPassenger?: number;
}

/** Builds the first catalog: the portal's tours, plus the user's own tours and ticket prices from older builds. */
async function buildInitialCatalog(): Promise<OfferedTour[]> {
  const catalog = cloneSeed();

  const rules = (await readJson<LegacyRule[]>(LEGACY_RULES_KEY)) ?? [];
  for (const rule of rules) {
    const keyword = (rule.tourKeyword ?? '').trim().toLowerCase();
    const price = rule.ticketCostPerPassenger ?? 0;
    if (!rule.isEnabled || keyword.length <= 2 || price <= 0) continue;
    for (const tour of catalog) {
      const tickets = tour.tickets ?? [];
      tickets.forEach((ticket) => {
        const hit =
          ticket.name.toLowerCase().replace(/’/g, "'").includes(keyword.replace(/’/g, "'")) ||
          (tickets.length === 1 && tour.title.toLowerCase().replace(/’/g, "'").includes(keyword.replace(/’/g, "'")));
        if (hit) ticket.pricePerPassenger = price;
      });
    }
  }

  const legacyTours = (await readJson<LegacyTour[]>(LEGACY_TOURS_KEY)) ?? [];
  for (const old of legacyTours) {
    if (!old?.gygUrl || LEGACY_SAMPLE_TOUR_IDS.has(old.id)) continue;
    const parsed = parseGygUrl(old.gygUrl);
    if (parsed && catalog.some((t) => t.gygTourId === parsed.tourId)) continue;
    const { ticketCostPerPassenger, ...rest } = old;
    catalog.push({
      ...rest,
      gygUrl: parsed?.url ?? old.gygUrl,
      gygTourId: parsed?.tourId,
      tickets: ticketCostPerPassenger ? [{ id: `tkt_${old.id}`, name: 'Tickets', pricePerPassenger: ticketCostPerPassenger }] : [],
    });
  }
  return catalog;
}

export async function getStoredOfferedTours(): Promise<OfferedTour[]> {
  const stored = await readJson<OfferedTour[]>(STORAGE_KEY_TOURS);
  if (Array.isArray(stored)) return stored;
  const initial = await buildInitialCatalog();
  await kv.setItem(STORAGE_KEY_TOURS, JSON.stringify(initial));
  return initial;
}

async function writeTours(tours: OfferedTour[]): Promise<OfferedTour[]> {
  await kv.setItem(STORAGE_KEY_TOURS, JSON.stringify(tours));
  return tours;
}

export async function saveOfferedTour(tour: OfferedTour): Promise<OfferedTour[]> {
  const current = await getStoredOfferedTours();
  const index = current.findIndex((t) => t.id === tour.id);
  return writeTours(index >= 0 ? current.map((t) => (t.id === tour.id ? tour : t)) : [tour, ...current]);
}

export async function deleteOfferedTour(id: string): Promise<OfferedTour[]> {
  return writeTours((await getStoredOfferedTours()).filter((t) => t.id !== id));
}

/** Updates one ticket's price against the latest stored catalog, so quick edits to sibling tickets don't overwrite each other. */
export async function setTicketPrice(tourId: string, ticketId: string, price: number): Promise<OfferedTour[]> {
  const current = await getStoredOfferedTours();
  return writeTours(
    current.map((t) =>
      t.id === tourId
        ? { ...t, tickets: (t.tickets ?? []).map((k): TourTicket => (k.id === ticketId ? { ...k, pricePerPassenger: price } : k)) }
        : t
    )
  );
}

/** Teaches the catalog that bookings titled `title` belong to `tourId` (and to no other tour). */
export async function addTourAlias(tourId: string, title: string): Promise<OfferedTour[]> {
  const alias = title.trim();
  const current = await getStoredOfferedTours();
  return writeTours(
    current.map((t) => {
      const others = (t.aliases ?? []).filter((a) => a !== alias);
      return t.id === tourId ? { ...t, aliases: [...others, alias] } : { ...t, aliases: others };
    })
  );
}

/** Link value meaning "this booking belongs to none of the tours". */
export const NO_TOUR = 'none';

/** Per-booking tour choices made by hand, keyed by booking reference. */
export async function getStoredBookingTourLinks(): Promise<Record<string, string>> {
  return (await readJson<Record<string, string>>(STORAGE_KEY_BOOKING_LINKS)) ?? {};
}

export async function setBookingTourLink(bookingRef: string, tourId: string | null): Promise<Record<string, string>> {
  const links = { ...(await getStoredBookingTourLinks()) };
  if (tourId) links[bookingRef] = tourId;
  else delete links[bookingRef];
  await kv.setItem(STORAGE_KEY_BOOKING_LINKS, JSON.stringify(links));
  return links;
}

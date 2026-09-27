import { OfferedTour } from '../types';
import { ItineraryStep, TOUR_CONTENT, TourContent, TourPrice } from './tourContent';

/** Portal content for a catalog tour, when it is one of the GetYourGuide products. */
export function tourContentFor(tour: OfferedTour | undefined | null): TourContent | undefined {
  return tour?.gygTourId ? TOUR_CONTENT[tour.gygTourId] : undefined;
}

/** 555 → "9 h 15 min", 35 → "35 min", 480 → "8 h". */
export function formatDuration(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = Math.round(minutes % 60);
  if (h === 0) return `${m} min`;
  return m === 0 ? `${h} h` : `${h} h ${m} min`;
}

/** "€250 per person" or "€420 per group". */
export function formatPrice(price: TourPrice): string {
  const amount = Number.isInteger(price.amount) ? String(price.amount) : price.amount.toFixed(2);
  return `€${amount} per ${price.per}`;
}

/** "2–7 guests" or "Up to 7 guests". */
export function formatGroupSize(price: TourPrice): string {
  return price.minTravellers > 1
    ? `${price.minTravellers}–${price.maxTravellers} guests`
    : `Up to ${price.maxTravellers} guests`;
}

/**
 * "10:00 AM", "9:00", "07:30" → "10:00" / "09:00" / "07:30" (24-hour), or null when it isn't a time.
 */
export function normalizeStartTime(raw: string | null | undefined): string | null {
  const match = raw?.trim().match(/^(\d{1,2}):(\d{2})\s*(AM|PM)?$/i);
  if (!match) return null;
  let hours = Number(match[1]);
  const suffix = match[3]?.toUpperCase();
  if (suffix === 'PM' && hours < 12) hours += 12;
  if (suffix === 'AM' && hours === 12) hours = 0;
  return `${String(hours).padStart(2, '0')}:${match[2]}`;
}

function clock(totalMinutes: number): string {
  const m = ((Math.round(totalMinutes) % 1440) + 1440) % 1440;
  return `${String(Math.floor(m / 60)).padStart(2, '0')}:${String(m % 60).padStart(2, '0')}`;
}

export type TimedStep = ItineraryStep & { at: string };

/** Each step with the clock time it begins, counted from the departure time. */
export function timedItinerary(steps: ItineraryStep[], start: string): TimedStep[] {
  const [h, m] = start.split(':').map(Number);
  let t = h * 60 + m;
  return steps.map((step) => {
    const at = clock(t);
    if (step.type === 'transfer' || step.type === 'stop') t += step.minutes;
    return { ...step, at };
  });
}

const MODE_LABEL: Record<string, string> = { van: 'Drive', car: 'Drive', 'cable car': 'Cable car' };

export function transferLabel(step: Extract<ItineraryStep, { type: 'transfer' }>): string {
  return `${MODE_LABEL[step.mode] ?? 'Transfer'} · ${formatDuration(step.minutes)}`;
}

/** Plain-text day plan for sending to a driver, e.g. over WhatsApp. */
export function itineraryText(tour: OfferedTour, content: TourContent, start: string): string {
  const lines = timedItinerary(content.itinerary, start).map((step) => {
    switch (step.type) {
      case 'pickup':
        return `${step.at}  Pickup – ${step.place}`;
      case 'dropoff':
        return `${step.at}  Drop-off – ${step.place}`;
      case 'transfer':
        return `        ${transferLabel(step)}`;
      default:
        return [
          `${step.at}  ${step.place} (${formatDuration(step.minutes)})`,
          step.included ? `        Included: ${step.included}` : null,
          step.note ? `        ${step.note}` : null,
        ]
          .filter(Boolean)
          .join('\n');
    }
  });
  return [
    tour.referenceCode ? `${tour.referenceCode} · ${tour.title}` : tour.title,
    `${formatDuration(content.durationMinutes)} · departs ${start}`,
    '',
    ...lines,
    content.itineraryApproximate ? '\nTimes are estimates.' : '',
  ]
    .join('\n')
    .trim();
}

/** "Fuschlsee, St. Gilgen on Wolfgangsee, Hallstatt, Gosausee (Dachstein)" */
export function stopNames(content: TourContent): string {
  return content.itinerary
    .filter((s): s is Extract<ItineraryStep, { type: 'stop' }> => s.type === 'stop')
    .map((s) => s.place)
    .join(', ');
}

import { BookingItem, Driver, getNumericPrice, isBookingReview, platformFeeRate } from '../types';
import { getBookingTicketDeduction, type TourMatcher } from './tours';
import { bookingMonthLabel } from './dates';

export { platformFeeRate };

export function platformName(b: BookingItem): string {
  return b.platform === 'airbnb' ? 'Airbnb' : 'GetYourGuide';
}

const eurFormatter = new Intl.NumberFormat('de-DE', {
  style: 'currency',
  currency: 'EUR',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const eurWholeFormatter = new Intl.NumberFormat('de-DE', {
  style: 'currency',
  currency: 'EUR',
  minimumFractionDigits: 0,
  maximumFractionDigits: 0,
});

export function formatEur(value: number): string {
  return eurFormatter.format(value);
}

/** "50% of net payout" or "150,00 € per tour". */
export function driverRateLabel(d: Driver): string {
  return d.payoutType === 'percentage'
    ? `${d.defaultPayoutRate}% of net payout`
    : `${formatEur(d.defaultPayoutRate)} per tour`;
}

/** Rounded euros for dense list rows, e.g. "560 €". */
export function formatEurWhole(value: number): string {
  return eurWholeFormatter.format(value);
}

export interface RevenueStats {
  gross: number;
  fee: number;
  net: number;
  ticketCosts: number;
  profit: number;
  count: number;
  normalGross: number;
  normalFee: number;
  normalNet: number;
  normalCount: number;
  reviewGross: number;
  reviewFee: number;
  reviewNet: number;
  reviewCount: number;
}

export function emptyRevenueStats(): RevenueStats {
  return {
    gross: 0,
    fee: 0,
    net: 0,
    ticketCosts: 0,
    profit: 0,
    count: 0,
    normalGross: 0,
    normalFee: 0,
    normalNet: 0,
    normalCount: 0,
    reviewGross: 0,
    reviewFee: 0,
    reviewNet: 0,
    reviewCount: 0,
  };
}

function addStats(a: RevenueStats, b: RevenueStats): RevenueStats {
  const out = emptyRevenueStats();
  (Object.keys(out) as (keyof RevenueStats)[]).forEach((k) => {
    out[k] = a[k] + b[k];
  });
  return out;
}

export const ALL_TIME = 'All Time';

export interface RevenueSummary {
  /** Month labels ("September 2026") in chronological order. */
  months: string[];
  byMonth: Record<string, RevenueStats>;
  allTime: RevenueStats;
}

/** Revenue grouped by tour month. Cancelled bookings never count toward revenue. */
export function computeRevenue(bookings: BookingItem[], matchTour: TourMatcher): RevenueSummary {
  const byMonth: Record<string, RevenueStats> = {};
  const monthOrder: Record<string, number> = {};

  bookings.forEach((b) => {
    if (b.status === 'cancelled') return;
    const month = bookingMonthLabel(b);
    const stats = (byMonth[month] ??= emptyRevenueStats());
    monthOrder[month] = Math.min(monthOrder[month] ?? Infinity, b.timestamp ?? Infinity);

    const price = getNumericPrice(b);
    const fee = price * platformFeeRate(b);
    const net = price - fee;
    const ticketCost = getBookingTicketDeduction(b, matchTour).totalCost;

    stats.gross += price;
    stats.fee += fee;
    stats.net += net;
    stats.ticketCosts += ticketCost;
    stats.profit += Math.max(0, net - ticketCost);
    stats.count += 1;

    if (isBookingReview(b)) {
      stats.reviewGross += price;
      stats.reviewFee += fee;
      stats.reviewNet += net;
      stats.reviewCount += 1;
    } else {
      stats.normalGross += price;
      stats.normalFee += fee;
      stats.normalNet += net;
      stats.normalCount += 1;
    }
  });

  const months = Object.keys(byMonth).sort((a, b) => monthOrder[a] - monthOrder[b]);
  const allTime = Object.values(byMonth).reduce(addStats, emptyRevenueStats());
  return { months, byMonth, allTime };
}

export function statsForMonth(summary: RevenueSummary, month: string): RevenueStats {
  if (month === ALL_TIME) return summary.allTime;
  return summary.byMonth[month] ?? emptyRevenueStats();
}

import AsyncStorage from '@react-native-async-storage/async-storage';
import { TourTicketRule, BookingItem, isBookingReview } from '../types';

const STORAGE_KEY_TICKET_RULES = '@pixelreview_ticket_rules';

export const DEFAULT_TICKET_RULES: TourTicketRule[] = [
  {
    id: 'rule_hallstatt_salt_mine',
    tourKeyword: 'Hallstatt Salt Mine',
    tourNamePattern: 'Hallstatt Salt Mine & Skywalk Private Tour',
    ticketCostPerPassenger: 49.0,
    description: 'Adult ticket €49 per passenger (Funicular & Salt Mine admission)',
    isEnabled: true,
    createdAt: Date.now() - 30 * 86400000,
  },
  {
    id: 'rule_eagles_nest',
    tourKeyword: 'Eagle\'s Nest',
    tourNamePattern: 'Eagle\'s Nest (Kehlsteinhaus) Private Tour',
    ticketCostPerPassenger: 32.0,
    description: 'Special mountain bus & brass elevator ticket €32 per passenger',
    isEnabled: true,
    createdAt: Date.now() - 15 * 86400000,
  },
];

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
  let foundMultiplier = false;

  while ((match = multiplierRegex.exec(text)) !== null) {
    const count = parseInt(match[1], 10);
    if (!isNaN(count) && count > 0) {
      totalFromMultipliers += count;
      foundMultiplier = true;
    }
  }

  if (foundMultiplier && totalFromMultipliers > 0) {
    return totalFromMultipliers;
  }

  // Pattern 2: "N Adult" or "N Participants" or "N Person"
  const wordRegex = /(\d+)\s*(?:adult|participant|person|child|guest|passenger|people)/i;
  const wordMatch = text.match(wordRegex);
  if (wordMatch) {
    const count = parseInt(wordMatch[1], 10);
    if (!isNaN(count) && count > 0) {
      return count;
    }
  }

  // Pattern 3: Any standalone number
  const anyNumMatch = text.match(/\b(\d+)\b/);
  if (anyNumMatch) {
    const count = parseInt(anyNumMatch[1], 10);
    if (!isNaN(count) && count > 0) {
      return count;
    }
  }

  return 1;
}

export async function getStoredTicketRules(): Promise<TourTicketRule[]> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY_TICKET_RULES);
    if (raw === null) {
      await AsyncStorage.setItem(
        STORAGE_KEY_TICKET_RULES,
        JSON.stringify(DEFAULT_TICKET_RULES)
      );
      return DEFAULT_TICKET_RULES;
    }
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch (err) {
    console.warn('Failed to load ticket rules:', err);
    return [];
  }
}

export async function saveTicketRule(
  rule: TourTicketRule
): Promise<TourTicketRule[]> {
  const current = await getStoredTicketRules();
  const index = current.findIndex((r) => r.id === rule.id);
  let updated: TourTicketRule[];
  if (index >= 0) {
    updated = [...current];
    updated[index] = rule;
  } else {
    updated = [rule, ...current];
  }
  await AsyncStorage.setItem(STORAGE_KEY_TICKET_RULES, JSON.stringify(updated));
  return updated;
}

export async function deleteTicketRule(id: string): Promise<TourTicketRule[]> {
  const current = await getStoredTicketRules();
  const updated = current.filter((r) => r.id !== id);
  await AsyncStorage.setItem(STORAGE_KEY_TICKET_RULES, JSON.stringify(updated));
  return updated;
}

export async function toggleTicketRule(id: string): Promise<TourTicketRule[]> {
  const current = await getStoredTicketRules();
  const updated = current.map((r) =>
    r.id === id ? { ...r, isEnabled: !r.isEnabled } : r
  );
  await AsyncStorage.setItem(STORAGE_KEY_TICKET_RULES, JSON.stringify(updated));
  return updated;
}

export interface TicketDeductionResult {
  hasDeduction: boolean;
  matchedRule: TourTicketRule | null;
  totalCost: number;
  passengerCount: number;
  costPerPassenger: number;
  fixedCost: number;
  breakdownText: string;
  grossPrice: number;
  netGygPayout: number; // 70% of gross
  netProfitAfterTickets: number; // 70% of gross minus ticket costs
}

function getNumericPrice(b: BookingItem): number {
  if (typeof b.priceAmount === 'number' && !isNaN(b.priceAmount)) return b.priceAmount;
  const num = parseFloat((b.price || '').replace(/[^0-9.,]/g, '').replace(',', '.'));
  return isNaN(num) ? 0 : num;
}

/**
 * Calculates ticket deductions for a booking.
 * Note: If booking is cancelled, ticket costs are 0!
 */
export function getBookingTicketDeduction(
  booking: BookingItem,
  rules: TourTicketRule[]
): TicketDeductionResult {
  const gross = getNumericPrice(booking);
  const netGyg = parseFloat((gross * 0.7).toFixed(2));

  // If tour was cancelled, no tickets were purchased
  if (booking.status === 'cancelled') {
    return {
      hasDeduction: false,
      matchedRule: null,
      totalCost: 0,
      passengerCount: 0,
      costPerPassenger: 0,
      fixedCost: 0,
      breakdownText: 'Cancelled (No tickets)',
      grossPrice: gross,
      netGygPayout: 0,
      netProfitAfterTickets: 0,
    };
  }

  // If review booking (< €30 or flagged as review), no tickets were purchased
  const isReview = isBookingReview(booking);

  if (isReview) {
    return {
      hasDeduction: false,
      matchedRule: null,
      totalCost: 0,
      passengerCount: 0,
      costPerPassenger: 0,
      fixedCost: 0,
      breakdownText: 'Review Booking (No tickets)',
      grossPrice: gross,
      netGygPayout: netGyg,
      netProfitAfterTickets: netGyg,
    };
  }

  const tourTitle = (booking.tourTitle || '').toLowerCase();

  // Find first matching enabled rule
  const matchedRule = rules.find((r) => {
    if (!r.isEnabled) return false;
    const keyword = (r.tourKeyword || '').trim().toLowerCase();
    return keyword.length > 2 && tourTitle.includes(keyword);
  });

  if (!matchedRule) {
    return {
      hasDeduction: false,
      matchedRule: null,
      totalCost: 0,
      passengerCount: parsePassengerCount(booking.participants),
      costPerPassenger: 0,
      fixedCost: 0,
      breakdownText: 'No ticket costs configured',
      grossPrice: gross,
      netGygPayout: netGyg,
      netProfitAfterTickets: netGyg,
    };
  }

  const passengers = parsePassengerCount(booking.participants);
  const perPersonTotal = passengers * matchedRule.ticketCostPerPassenger;
  const fixedCost = matchedRule.fixedBookingCost || 0;
  const totalCost = parseFloat((perPersonTotal + fixedCost).toFixed(2));
  const netProfitAfterTickets = parseFloat((netGyg - totalCost).toFixed(2));

  let breakdownText = `${passengers} × €${matchedRule.ticketCostPerPassenger.toFixed(2)}`;
  if (fixedCost > 0) {
    breakdownText += ` + €${fixedCost.toFixed(2)} fixed`;
  }

  return {
    hasDeduction: true,
    matchedRule,
    totalCost,
    passengerCount: passengers,
    costPerPassenger: matchedRule.ticketCostPerPassenger,
    fixedCost,
    breakdownText,
    grossPrice: gross,
    netGygPayout: netGyg,
    netProfitAfterTickets,
  };
}

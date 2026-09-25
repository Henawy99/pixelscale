import AsyncStorage from '@react-native-async-storage/async-storage';
import { Driver, DriverAssignment, BookingItem } from '../types';

const STORAGE_KEY_DRIVERS = '@pixelreview_drivers';
const STORAGE_KEY_ASSIGNMENTS = '@pixelreview_driver_assignments';

export const DEFAULT_DRIVERS: Driver[] = [
  {
    id: 'drv_marco',
    name: 'Marco Rossi',
    phone: '+43 664 1234567',
    payoutType: 'percentage',
    defaultPayoutRate: 50, // 50% of net GYG payout
    color: '#3b82f6',
    notes: 'Primary driver for Hallstatt & Berchtesgaden private tours',
    createdAt: Date.now() - 30 * 86400000,
  },
  {
    id: 'drv_stefan',
    name: 'Stefan Gruber',
    phone: '+43 676 9876543',
    payoutType: 'fixed',
    defaultPayoutRate: 150, // €150 fixed per tour
    color: '#10b981',
    notes: 'Salzburg & Eagle\'s Nest Specialist',
    createdAt: Date.now() - 15 * 86400000,
  },
];

export async function getStoredDrivers(): Promise<Driver[]> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY_DRIVERS);
    if (raw === null) {
      await AsyncStorage.setItem(STORAGE_KEY_DRIVERS, JSON.stringify(DEFAULT_DRIVERS));
      return DEFAULT_DRIVERS;
    }
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : [];
  } catch (err) {
    console.warn('Failed to load drivers:', err);
    return [];
  }
}

export async function saveDriver(driver: Driver): Promise<Driver[]> {
  const current = await getStoredDrivers();
  const index = current.findIndex((d) => d.id === driver.id);
  let updated: Driver[];
  if (index >= 0) {
    updated = [...current];
    updated[index] = driver;
  } else {
    updated = [driver, ...current];
  }
  await AsyncStorage.setItem(STORAGE_KEY_DRIVERS, JSON.stringify(updated));
  return updated;
}

export async function deleteDriver(id: string): Promise<Driver[]> {
  const current = await getStoredDrivers();
  const updated = current.filter((d) => d.id !== id);
  await AsyncStorage.setItem(STORAGE_KEY_DRIVERS, JSON.stringify(updated));

  // Also clean up any booking assignments associated with this deleted driver
  try {
    const rawAssignments = await AsyncStorage.getItem(STORAGE_KEY_ASSIGNMENTS);
    if (rawAssignments) {
      const assignments = JSON.parse(rawAssignments);
      let changed = false;
      for (const ref of Object.keys(assignments)) {
        if (assignments[ref]?.driverId === id) {
          delete assignments[ref];
          changed = true;
        }
      }
      if (changed) {
        await AsyncStorage.setItem(STORAGE_KEY_ASSIGNMENTS, JSON.stringify(assignments));
      }
    }
  } catch (err) {
    console.warn('Failed to clean assignments for deleted driver:', err);
  }

  return updated;
}

export async function getStoredAssignments(): Promise<Record<string, DriverAssignment>> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY_ASSIGNMENTS);
    if (!raw) return {};
    return JSON.parse(raw);
  } catch (err) {
    console.warn('Failed to load driver assignments:', err);
    return {};
  }
}

export async function assignDriverToBooking(
  bookingRef: string,
  driverId: string,
  customPayoutAmount?: number
): Promise<Record<string, DriverAssignment>> {
  const current = await getStoredAssignments();
  current[bookingRef] = {
    bookingRef,
    driverId,
    assignedAt: Date.now(),
    customPayoutAmount,
  };
  await AsyncStorage.setItem(STORAGE_KEY_ASSIGNMENTS, JSON.stringify(current));
  return { ...current };
}

export async function unassignDriverFromBooking(
  bookingRef: string
): Promise<Record<string, DriverAssignment>> {
  const current = await getStoredAssignments();
  delete current[bookingRef];
  await AsyncStorage.setItem(STORAGE_KEY_ASSIGNMENTS, JSON.stringify(current));
  return { ...current };
}

function getNumericPrice(b: BookingItem): number {
  if (typeof b.priceAmount === 'number' && !isNaN(b.priceAmount)) return b.priceAmount;
  const num = parseFloat((b.price || '').replace(/[^0-9.,]/g, '').replace(',', '.'));
  return isNaN(num) ? 0 : num;
}

/**
 * Calculates a driver's payout for a given booking.
 * Crucial Rule: Cancelled bookings NEVER receive payout (€0.00).
 */
export function calculateDriverTourPayout(
  booking: BookingItem,
  driver: Driver,
  customPayoutAmount?: number
): number {
  if (booking.status === 'cancelled') {
    return 0;
  }

  if (typeof customPayoutAmount === 'number' && !isNaN(customPayoutAmount)) {
    return customPayoutAmount;
  }

  const gross = getNumericPrice(booking);
  const netGyg = gross * 0.7; // 30% GYG commission deducted

  if (driver.payoutType === 'percentage') {
    const rate = Math.max(0, Math.min(100, driver.defaultPayoutRate || 50));
    return parseFloat((netGyg * (rate / 100)).toFixed(2));
  } else {
    // Fixed amount per tour
    return parseFloat((driver.defaultPayoutRate || 0).toFixed(2));
  }
}

export interface DriverTourDetail {
  booking: BookingItem;
  assignment: DriverAssignment;
  payout: number;
  isPast: boolean;
  isCancelled: boolean;
}

export interface DriverStatistics {
  driver: Driver;
  totalEarnings: number;
  totalToursCount: number;
  activeToursCount: number;
  cancelledToursCount: number;
  upcomingCount: number;
  completedCount: number;
  tours: DriverTourDetail[];
}

export function computeDriverStatistics(
  driver: Driver,
  bookings: BookingItem[],
  assignments: Record<string, DriverAssignment>
): DriverStatistics {
  const now = Date.now();
  const assignedTours: DriverTourDetail[] = [];
  let totalEarnings = 0;
  let activeToursCount = 0;
  let cancelledToursCount = 0;
  let upcomingCount = 0;
  let completedCount = 0;

  bookings.forEach((b) => {
    const assignment = assignments[b.referenceNumber];
    if (assignment && assignment.driverId === driver.id) {
      const isCancelled = b.status === 'cancelled';
      const payout = calculateDriverTourPayout(b, driver, assignment.customPayoutAmount);
      const tourTimestamp = b.timestamp || Date.now();
      const isPast = tourTimestamp < now;

      if (isCancelled) {
        cancelledToursCount++;
      } else {
        totalEarnings += payout;
        activeToursCount++;
        if (isPast) {
          completedCount++;
        } else {
          upcomingCount++;
        }
      }

      assignedTours.push({
        booking: b,
        assignment,
        payout,
        isPast,
        isCancelled,
      });
    }
  });

  // Sort newest tours first
  assignedTours.sort(
    (a, b) => (b.booking.timestamp || 0) - (a.booking.timestamp || 0)
  );

  return {
    driver,
    totalEarnings: parseFloat(totalEarnings.toFixed(2)),
    totalToursCount: assignedTours.length,
    activeToursCount,
    cancelledToursCount,
    upcomingCount,
    completedCount,
    tours: assignedTours,
  };
}

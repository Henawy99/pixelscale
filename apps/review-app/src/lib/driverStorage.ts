import { kv } from './storage';
import { Driver, DriverAssignment, BookingItem, getNumericPrice, platformFeeRate } from '../types';

const STORAGE_KEY_DRIVERS = '@pixelreview_drivers';
const STORAGE_KEY_ASSIGNMENTS = '@pixelreview_driver_assignments';

// Placeholder drivers that earlier builds created on first launch. Untouched copies are hidden;
// edited ones are real data and stay.
const SAMPLE_DRIVERS = new Set(['drv_marco|Marco Rossi|+43 664 1234567', 'drv_stefan|Stefan Gruber|+43 676 9876543']);
const isSample = (d: Driver) => SAMPLE_DRIVERS.has(`${d.id}|${d.name}|${d.phone}`);

/** Throws when the stored list can't be read, so a save never overwrites it with a partial list. */
async function readDrivers(): Promise<Driver[]> {
  const raw = await kv.getItem(STORAGE_KEY_DRIVERS);
  const parsed = raw ? JSON.parse(raw) : [];
  return Array.isArray(parsed) ? parsed.filter((d: Driver) => !isSample(d)) : [];
}

export async function getStoredDrivers(): Promise<Driver[]> {
  try {
    return await readDrivers();
  } catch (err) {
    console.warn('Failed to load drivers:', err);
    return [];
  }
}

export async function saveDriver(driver: Driver): Promise<Driver[]> {
  const current = await readDrivers();
  const index = current.findIndex((d) => d.id === driver.id);
  let updated: Driver[];
  if (index >= 0) {
    updated = [...current];
    updated[index] = driver;
  } else {
    updated = [driver, ...current];
  }
  await kv.setItem(STORAGE_KEY_DRIVERS, JSON.stringify(updated));
  return updated;
}

export async function deleteDriver(id: string): Promise<Driver[]> {
  const current = await readDrivers();
  const updated = current.filter((d) => d.id !== id);
  await kv.setItem(STORAGE_KEY_DRIVERS, JSON.stringify(updated));

  // Also clean up any booking assignments associated with this deleted driver
  try {
    const rawAssignments = await kv.getItem(STORAGE_KEY_ASSIGNMENTS);
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
        await kv.setItem(STORAGE_KEY_ASSIGNMENTS, JSON.stringify(assignments));
      }
    }
  } catch (err) {
    console.warn('Failed to clean assignments for deleted driver:', err);
  }

  return updated;
}

export async function getStoredAssignments(): Promise<Record<string, DriverAssignment>> {
  try {
    const raw = await kv.getItem(STORAGE_KEY_ASSIGNMENTS);
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
  await kv.setItem(STORAGE_KEY_ASSIGNMENTS, JSON.stringify(current));
  return { ...current };
}

export async function unassignDriverFromBooking(
  bookingRef: string
): Promise<Record<string, DriverAssignment>> {
  const current = await getStoredAssignments();
  delete current[bookingRef];
  await kv.setItem(STORAGE_KEY_ASSIGNMENTS, JSON.stringify(current));
  return { ...current };
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
  const netGyg = gross * (1 - platformFeeRate(booking));

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

import { createContext, use, useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { AppState } from 'react-native';
import {
  AnalyzeResponse,
  BookingItem,
  BookingsResponse,
  Driver,
  DriverAssignment,
  HistoryItem,
  OfferedTour,
  Reviewer,
  ReviewerAssignment,
} from '../types';
import { fetchLiveBookings } from '../api/client';
import {
  assignDriverToBooking,
  deleteDriver as deleteStoredDriver,
  getStoredAssignments,
  getStoredDrivers,
  saveDriver as saveStoredDriver,
  unassignDriverFromBooking,
} from '../lib/driverStorage';
import {
  assignReviewerToBooking,
  deleteReviewer as deleteStoredReviewer,
  getStoredReviewerAssignments,
  getStoredReviewers,
  saveReviewer as saveStoredReviewer,
  unassignReviewerFromBooking,
} from '../lib/reviewerStorage';
import {
  addTourAlias,
  deleteOfferedTour,
  getStoredBookingTourLinks,
  getStoredOfferedTours,
  saveOfferedTour,
  setBookingTourLink,
  setTicketPrice,
} from '../lib/toursStorage';
import { createTourMatcher, type TourMatcher } from '../lib/tours';
import { addHistoryItem, deleteHistoryItem, getStoredHistory } from '../lib/historyStorage';

const AUTO_SYNC_MS = 45_000;

export interface SyncState {
  isLoading: boolean;
  isSyncing: boolean;
  source: BookingsResponse['source'] | null;
  lastSyncedAt: string;
  error: string | null;
}

interface AppData {
  bookings: BookingItem[];
  drivers: Driver[];
  assignments: Record<string, DriverAssignment>;
  reviewers: Reviewer[];
  reviewerAssignments: Record<string, ReviewerAssignment>;
  /** The GetYourGuide product catalog, with each tour's included tickets. */
  offeredTours: OfferedTour[];
  /** Which catalog tour a booking belongs to (memoised; changes identity when tours or links change). */
  matchTour: TourMatcher;
  /** Tours chosen by hand per booking reference (a tour id or NO_TOUR). */
  tourLinks: Record<string, string>;
  history: HistoryItem[];
  sync: SyncState;

  /** Force-syncs bookings from the mail server. Resolves with the outcome for UI feedback. */
  refresh: () => Promise<SyncResult>;

  assignDriver: (bookingRef: string, driverId: string, customPayout?: number) => Promise<void>;
  unassignDriver: (bookingRef: string) => Promise<void>;
  saveDriver: (driver: Driver) => Promise<void>;
  deleteDriver: (id: string) => Promise<void>;

  assignReviewer: (
    bookingRef: string,
    reviewerId: string,
    reviewText?: string,
    photoUrls?: string[],
    notes?: string
  ) => Promise<void>;
  unassignReviewer: (bookingRef: string) => Promise<void>;
  saveReviewer: (reviewer: Reviewer) => Promise<void>;
  deleteReviewer: (id: string) => Promise<void>;

  saveTour: (tour: OfferedTour) => Promise<void>;
  deleteTour: (id: string) => Promise<void>;
  setTicketPrice: (tourId: string, ticketId: string, price: number) => Promise<void>;
  /** Makes every booking titled `title` (now and in future) belong to `tourId`. */
  addTourAlias: (tourId: string, title: string) => Promise<void>;
  /** Pins one booking to a tour; `null` goes back to automatic matching, NO_TOUR means none. */
  linkBookingToTour: (bookingRef: string, tourId: string | null) => Promise<void>;

  addHistory: (res: AnalyzeResponse) => Promise<void>;
  deleteHistory: (id: string) => Promise<void>;
}

export type SyncResult =
  | { ok: true; data: BookingsResponse }
  | { ok: false; error: string };

const AppDataContext = createContext<AppData | null>(null);

export function AppDataProvider({ children }: { children: ReactNode }) {
  const [bookings, setBookings] = useState<BookingItem[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [assignments, setAssignments] = useState<Record<string, DriverAssignment>>({});
  const [reviewers, setReviewers] = useState<Reviewer[]>([]);
  const [reviewerAssignments, setReviewerAssignments] = useState<Record<string, ReviewerAssignment>>({});
  const [offeredTours, setOfferedTours] = useState<OfferedTour[]>([]);
  const [tourLinks, setTourLinks] = useState<Record<string, string>>({});
  const matchTour = useMemo(() => createTourMatcher(offeredTours, tourLinks), [offeredTours, tourLinks]);
  const [history, setHistory] = useState<HistoryItem[]>([]);
  const [sync, setSync] = useState<SyncState>({
    isLoading: true,
    isSyncing: false,
    source: null,
    lastSyncedAt: '',
    error: null,
  });
  const inFlight = useRef(false);

  const loadBookings = useCallback(async (initial: boolean): Promise<SyncResult> => {
    if (inFlight.current) return { ok: false, error: 'A sync is already running.' };
    inFlight.current = true;
    setSync((s) => ({ ...s, isLoading: initial, isSyncing: !initial, error: null }));
    try {
      const data = await fetchLiveBookings(!initial);
      if (data.success && Array.isArray(data.bookings)) {
        setBookings(data.bookings);
      }
      setSync((s) => ({
        ...s,
        source: data.source ?? null,
        lastSyncedAt: data.success ? data.lastSyncedAt || new Date().toISOString() : s.lastSyncedAt,
        error: data.error ?? null,
      }));
      return data.success ? { ok: true, data } : { ok: false, error: data.error || 'Server did not return bookings.' };
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to fetch bookings';
      setSync((s) => ({ ...s, error: msg }));
      return { ok: false, error: msg };
    } finally {
      inFlight.current = false;
      setSync((s) => ({ ...s, isLoading: false, isSyncing: false }));
    }
  }, []);

  // Local data first (a few ms from SQLite), then the first sync, so bookings arrive with their
  // drivers, reviewers and tours already known.
  useEffect(() => {
    (async () => {
      const [d, a, r, ra, tours, links, h] = await Promise.all([
        getStoredDrivers(),
        getStoredAssignments(),
        getStoredReviewers(),
        getStoredReviewerAssignments(),
        getStoredOfferedTours(),
        getStoredBookingTourLinks(),
        getStoredHistory(),
      ]);
      setDrivers(d);
      setAssignments(a);
      setReviewers(r);
      setReviewerAssignments(ra);
      setOfferedTours(tours);
      setTourLinks(links);
      setHistory(h);
      await loadBookings(true);
    })();
  }, [loadBookings]);

  // Background auto-sync while the app is in the foreground.
  useEffect(() => {
    let interval: ReturnType<typeof setInterval> | null = null;
    const start = () => {
      if (!interval) interval = setInterval(() => loadBookings(false), AUTO_SYNC_MS);
    };
    const stop = () => {
      if (interval) clearInterval(interval);
      interval = null;
    };
    start();
    const sub = AppState.addEventListener('change', (state) => {
      if (state === 'active') {
        loadBookings(false);
        start();
      } else {
        stop();
      }
    });
    return () => {
      stop();
      sub.remove();
    };
  }, [loadBookings]);

  const value = useMemo<AppData>(
    () => ({
      bookings,
      drivers,
      assignments,
      reviewers,
      reviewerAssignments,
      offeredTours,
      matchTour,
      tourLinks,
      history,
      sync,

      refresh: () => loadBookings(false),

      assignDriver: async (ref, driverId, customPayout) => {
        setAssignments(await assignDriverToBooking(ref, driverId, customPayout));
      },
      unassignDriver: async (ref) => {
        setAssignments(await unassignDriverFromBooking(ref));
      },
      saveDriver: async (driver) => {
        setDrivers(await saveStoredDriver(driver));
      },
      deleteDriver: async (id) => {
        setDrivers(await deleteStoredDriver(id));
        setAssignments(await getStoredAssignments());
      },

      assignReviewer: async (ref, reviewerId, reviewText, photoUrls, notes) => {
        setReviewerAssignments({
          ...(await assignReviewerToBooking(ref, reviewerId, reviewText, photoUrls, notes)),
        });
      },
      unassignReviewer: async (ref) => {
        setReviewerAssignments({ ...(await unassignReviewerFromBooking(ref)) });
      },
      saveReviewer: async (reviewer) => {
        setReviewers(await saveStoredReviewer(reviewer));
      },
      deleteReviewer: async (id) => {
        setReviewers(await deleteStoredReviewer(id));
        setReviewerAssignments(await getStoredReviewerAssignments());
      },

      saveTour: async (tour) => {
        setOfferedTours(await saveOfferedTour(tour));
      },
      deleteTour: async (id) => {
        setOfferedTours(await deleteOfferedTour(id));
      },
      setTicketPrice: async (tourId, ticketId, price) => {
        setOfferedTours(await setTicketPrice(tourId, ticketId, price));
      },
      addTourAlias: async (tourId, title) => {
        setOfferedTours(await addTourAlias(tourId, title));
      },
      linkBookingToTour: async (ref, tourId) => {
        setTourLinks(await setBookingTourLink(ref, tourId));
      },

      addHistory: async (res) => {
        const item = await addHistoryItem(res);
        if (item) setHistory((h) => [item, ...h]);
      },
      deleteHistory: async (id) => {
        setHistory(await deleteHistoryItem(id));
      },
    }),
    [
      bookings,
      drivers,
      assignments,
      reviewers,
      reviewerAssignments,
      offeredTours,
      matchTour,
      tourLinks,
      history,
      sync,
      loadBookings,
    ]
  );

  return <AppDataContext value={value}>{children}</AppDataContext>;
}

export function useAppData(): AppData {
  const ctx = use(AppDataContext);
  if (!ctx) throw new Error('useAppData must be used inside <AppDataProvider>');
  return ctx;
}

export function useBooking(ref: string | undefined): BookingItem | undefined {
  const { bookings } = useAppData();
  return useMemo(() => bookings.find((b) => b.referenceNumber === ref), [bookings, ref]);
}

import React, { useState, useEffect, useCallback } from 'react';
import { StyleSheet, View } from 'react-native';
import { SafeAreaProvider, SafeAreaView } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';
import AsyncStorage from '@react-native-async-storage/async-storage';
import {
  BookingItem,
  ActiveTab,
  HistoryItem,
  AnalyzeResponse,
  Driver,
  DriverAssignment,
  TourTicketRule,
} from './src/types';
import { fetchLiveBookings } from './src/api/client';
import {
  getStoredDrivers,
  getStoredAssignments,
  assignDriverToBooking,
  unassignDriverFromBooking,
} from './src/lib/driverStorage';
import { getStoredTicketRules } from './src/lib/ticketRulesStorage';
import { Header } from './src/components/Header';
import { BottomNav } from './src/components/BottomNav';
import { BookingsScreen } from './src/screens/BookingsScreen';
import { CalendarScreen } from './src/screens/CalendarScreen';
import { DriversScreen } from './src/screens/DriversScreen';
import { StudioScreen } from './src/screens/StudioScreen';
import { HistoryScreen } from './src/screens/HistoryScreen';
import { SettingsScreen } from './src/screens/SettingsScreen';

const STORAGE_KEY_HISTORY = '@pixelreview_history';

export default function App() {
  const [activeTab, setActiveTab] = useState<ActiveTab>('bookings');
  const [bookings, setBookings] = useState<BookingItem[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [assignments, setAssignments] = useState<Record<string, DriverAssignment>>({});
  const [ticketRules, setTicketRules] = useState<TourTicketRule[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [isSyncing, setIsSyncing] = useState(false);
  const [isZohoConnected, setIsZohoConnected] = useState(false);
  const [lastSyncedAt, setLastSyncedAt] = useState('');
  const [syncError, setSyncError] = useState<string | null>(null);

  // Studio pre-fill state
  const [prefilledUrl, setPrefilledUrl] = useState('');
  const [prefilledNotes, setPrefilledNotes] = useState('');

  // History state
  const [history, setHistory] = useState<HistoryItem[]>([]);

  // Load drivers and assignments from AsyncStorage
  const loadDriversData = useCallback(async () => {
    try {
      const [d, a] = await Promise.all([
        getStoredDrivers(),
        getStoredAssignments(),
      ]);
      setDrivers(d);
      setAssignments(a);
    } catch (err) {
      console.warn('Failed to load drivers/assignments:', err);
    }
  }, []);

  // Load ticket rules from AsyncStorage
  const loadTicketRules = useCallback(async () => {
    try {
      const rules = await getStoredTicketRules();
      setTicketRules(rules);
    } catch (err) {
      console.warn('Failed to load ticket rules:', err);
    }
  }, []);

  // Load history from AsyncStorage
  useEffect(() => {
    (async () => {
      try {
        const stored = await AsyncStorage.getItem(STORAGE_KEY_HISTORY);
        if (stored) {
          setHistory(JSON.parse(stored));
        }
      } catch {
        // ignore
      }
    })();
    loadDriversData();
    loadTicketRules();
  }, [loadDriversData, loadTicketRules]);

  // Handle assigning driver to booking
  const handleAssignDriver = async (
    bookingRef: string,
    driverId: string,
    customPayout?: number
  ) => {
    const updated = await assignDriverToBooking(bookingRef, driverId, customPayout);
    setAssignments(updated);
  };

  // Handle unassigning driver from booking
  const handleUnassignDriver = async (bookingRef: string) => {
    const updated = await unassignDriverFromBooking(bookingRef);
    setAssignments(updated);
  };

  // Fetch bookings function
  const loadBookings = useCallback(async (isInitial = false) => {
    if (isInitial) {
      setIsLoading(true);
    } else {
      setIsSyncing(true);
    }
    setSyncError(null);

    try {
      const data = await fetchLiveBookings(!isInitial);
      if (data.source === 'zoho') {
        setIsZohoConnected(true);
      } else {
        setIsZohoConnected(false);
      }

      if (data.success && Array.isArray(data.bookings)) {
        setBookings(data.bookings);
        setLastSyncedAt(data.lastSyncedAt || new Date().toISOString());
      }

      if (data.error) {
        setSyncError(data.error);
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Failed to fetch bookings';
      setSyncError(msg);
    } finally {
      setIsLoading(false);
      setIsSyncing(false);
    }
  }, []);

  // Initial load & 45-second background auto-sync
  useEffect(() => {
    loadBookings(true);
    const interval = setInterval(() => {
      loadBookings(false);
    }, 45000);
    return () => clearInterval(interval);
  }, [loadBookings]);

  // Jump from BookingCard to Studio
  const handleGenerateFromBooking = (booking: BookingItem) => {
    setPrefilledUrl(booking.tourTitle || booking.bookingUrl || '');
    setPrefilledNotes(
      `Booking Reference: ${booking.referenceNumber}\nCustomer: ${booking.customerName}\nTour: ${booking.tourTitle}\nDate: ${booking.date}\nPickup: ${booking.pickup || 'Salzburg'}`
    );
    setActiveTab('studio');
  };

  // Save generated review to history
  const handleSaveToHistory = async (res: AnalyzeResponse) => {
    if (!res.review || !res.tour) return;
    const newItem: HistoryItem = {
      id: String(Date.now()),
      timestamp: Date.now(),
      tour: res.tour,
      review: res.review,
      photos: res.photos || [],
    };
    const updated = [newItem, ...history];
    setHistory(updated);
    await AsyncStorage.setItem(STORAGE_KEY_HISTORY, JSON.stringify(updated));
  };

  // Delete history item
  const handleDeleteHistory = async (id: string) => {
    const updated = history.filter((h) => h.id !== id);
    setHistory(updated);
    await AsyncStorage.setItem(STORAGE_KEY_HISTORY, JSON.stringify(updated));
  };

  return (
    <SafeAreaProvider>
      <SafeAreaView style={styles.safeArea} edges={['top', 'left', 'right']}>
        <StatusBar style="dark" />

        {/* Global Header */}
        <Header
          isZohoConnected={isZohoConnected}
          isSyncing={isSyncing}
          onRefresh={() => loadBookings(false)}
          onOpenSettings={() => setActiveTab('settings')}
        />

        {/* Tab Body */}
        <View style={styles.body}>
          {activeTab === 'bookings' && (
            <BookingsScreen
              bookings={bookings}
              drivers={drivers}
              assignments={assignments}
              ticketRules={ticketRules}
              isLoading={isLoading}
              isSyncing={isSyncing}
              isZohoConnected={isZohoConnected}
              lastSyncedAt={lastSyncedAt}
              syncError={syncError}
              onRefresh={() => loadBookings(false)}
              onGenerateReview={handleGenerateFromBooking}
              onAssignDriver={handleAssignDriver}
              onUnassignDriver={handleUnassignDriver}
            />
          )}

          {activeTab === 'calendar' && (
            <CalendarScreen
              bookings={bookings}
              drivers={drivers}
              assignments={assignments}
              ticketRules={ticketRules}
              onAssignDriver={handleAssignDriver}
              onUnassignDriver={handleUnassignDriver}
              onGenerateReview={handleGenerateFromBooking}
            />
          )}

          {activeTab === 'drivers' && (
            <DriversScreen
              bookings={bookings}
              drivers={drivers}
              assignments={assignments}
              onDriversUpdated={loadDriversData}
            />
          )}

          {activeTab === 'studio' && (
            <StudioScreen
              prefilledUrl={prefilledUrl}
              prefilledNotes={prefilledNotes}
              onClearPrefill={() => {
                setPrefilledUrl('');
                setPrefilledNotes('');
              }}
              onSaveToHistory={handleSaveToHistory}
            />
          )}

          {activeTab === 'history' && (
            <HistoryScreen
              history={history}
              onDeleteHistoryItem={handleDeleteHistory}
              onSelectHistoryItem={(item) => {
                setPrefilledUrl(item.tour?.title || '');
                setActiveTab('studio');
              }}
            />
          )}

          {activeTab === 'settings' && (
            <SettingsScreen
              bookings={bookings}
              ticketRules={ticketRules}
              onTicketRulesUpdated={loadTicketRules}
              onSettingsSaved={() => {
                loadBookings(false);
              }}
            />
          )}
        </View>

        {/* Native Bottom Navigation Bar */}
        <BottomNav
          activeTab={activeTab}
          onSelectTab={setActiveTab}
          bookingsCount={bookings.length}
        />
      </SafeAreaView>
    </SafeAreaProvider>
  );
}

const styles = StyleSheet.create({
  safeArea: {
    flex: 1,
    backgroundColor: '#ffffff',
  },
  body: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
});

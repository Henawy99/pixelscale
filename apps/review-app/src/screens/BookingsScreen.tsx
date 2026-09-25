import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  FlatList,
  TextInput,
  RefreshControl,
  ActivityIndicator,
} from 'react-native';
import { Search, AlertCircle, CheckCircle2 } from 'lucide-react-native';
import {
  BookingItem,
  FilterType,
  Driver,
  DriverAssignment,
  TourTicketRule,
  Reviewer,
  ReviewerAssignment,
} from '../types';
import { RevenueCard } from '../components/RevenueCard';
import { FilterTabs } from '../components/FilterTabs';
import { BookingCard } from '../components/BookingCard';

interface BookingsScreenProps {
  bookings: BookingItem[];
  drivers?: Driver[];
  assignments?: Record<string, DriverAssignment>;
  ticketRules?: TourTicketRule[];
  reviewers?: Reviewer[];
  reviewerAssignments?: Record<string, ReviewerAssignment>;
  isLoading: boolean;
  isSyncing: boolean;
  isZohoConnected: boolean;
  lastSyncedAt: string;
  syncError: string | null;
  onRefresh: () => void;
  onGenerateReview: (booking: BookingItem) => void;
  onAssignDriver?: (bookingRef: string, driverId: string, customPayout?: number) => void;
  onUnassignDriver?: (bookingRef: string) => void;
  onAssignReviewer?: (
    bookingRef: string,
    reviewerId: string,
    reviewText?: string,
    photoUrls?: string[],
    notes?: string
  ) => void;
  onUnassignReviewer?: (bookingRef: string) => void;
}

function getNumericPrice(b: BookingItem): number {
  if (typeof b.priceAmount === 'number' && !isNaN(b.priceAmount)) return b.priceAmount;
  const num = parseFloat((b.price || '').replace(/[^0-9.,]/g, '').replace(',', '.'));
  return isNaN(num) ? 0 : num;
}

function isBookingReview(b: BookingItem): boolean {
  if (typeof b.isReviewBooking === 'boolean') return b.isReviewBooking;
  const price = getNumericPrice(b);
  return price > 0 && price < 30;
}

export function BookingsScreen({
  bookings,
  drivers = [],
  assignments = {},
  ticketRules = [],
  reviewers = [],
  reviewerAssignments = {},
  isLoading,
  isSyncing,
  isZohoConnected,
  lastSyncedAt,
  syncError,
  onRefresh,
  onGenerateReview,
  onAssignDriver,
  onUnassignDriver,
  onAssignReviewer,
  onUnassignReviewer,
}: BookingsScreenProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedFilter, setSelectedFilter] = useState<FilterType>('normal');

  const filteredBookings = useMemo(() => {
    return bookings.filter((b) => {
      const isReview = isBookingReview(b);

      // Filter category
      if (selectedFilter === 'normal' && (isReview || b.status === 'cancelled')) return false;
      if (selectedFilter === 'review' && (!isReview || b.status === 'cancelled')) return false;
      if (selectedFilter === 'last-minute' && (!b.isLastMinute || b.status === 'cancelled')) return false;
      if (selectedFilter === 'confirmed' && b.status !== 'confirmed') return false;
      if (selectedFilter === 'cancelled' && b.status !== 'cancelled') return false;

      // Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const ref = b.referenceNumber.toLowerCase();
        const title = b.tourTitle.toLowerCase();
        const cust = (b.customerName || '').toLowerCase();
        const phone = (b.customerPhone || '').toLowerCase();
        const pickup = (b.pickup || '').toLowerCase();
        return ref.includes(q) || title.includes(q) || cust.includes(q) || phone.includes(q) || pickup.includes(q);
      }
      return true;
    });
  }, [bookings, selectedFilter, searchQuery]);

  const counts = useMemo(() => {
    let normal = 0;
    let review = 0;
    let lastMinute = 0;
    let confirmed = 0;
    let cancelled = 0;

    bookings.forEach((b) => {
      if (b.status === 'cancelled') {
        cancelled++;
        return;
      }
      if (b.status === 'confirmed') confirmed++;
      if (b.isLastMinute) lastMinute++;
      if (isBookingReview(b)) {
        review++;
      } else {
        normal++;
      }
    });

    return {
      all: bookings.length,
      normal,
      review,
      lastMinute,
      confirmed,
      cancelled,
    };
  }, [bookings]);

  return (
    <View style={styles.container}>
      {/* Search Input Bar */}
      <View style={styles.searchWrapper}>
        <View style={styles.searchBar}>
          <Search size={16} color="#94a3b8" />
          <TextInput
            placeholder="Search booking ref, customer, tour, or pickup..."
            placeholderTextColor="#94a3b8"
            value={searchQuery}
            onChangeText={setSearchQuery}
            style={styles.searchInput}
            clearButtonMode="while-editing"
          />
        </View>
      </View>

      <FlatList
        data={filteredBookings}
        keyExtractor={(item) => item.id || item.referenceNumber}
        showsVerticalScrollIndicator={false}
        refreshControl={
          <RefreshControl
            refreshing={isSyncing}
            onRefresh={onRefresh}
            tintColor="#4f46e5"
            colors={['#4f46e5']}
          />
        }
        ListHeaderComponent={
          <>
            {/* Revenue Overview Card */}
            <RevenueCard bookings={bookings} ticketRules={ticketRules} />

            {/* Connection Banner */}
            <View style={styles.bannerWrapper}>
              {isZohoConnected ? (
                <View style={styles.liveBanner}>
                  <CheckCircle2 size={15} color="#059669" />
                  <Text style={styles.liveBannerText}>
                    Zoho IMAP Connected · {bookings.length} Bookings Loaded
                  </Text>
                </View>
              ) : (
                <View style={styles.demoBanner}>
                  <AlertCircle size={15} color="#d97706" />
                  <Text style={styles.demoBannerText}>
                    Connecting to live Zoho Mail inbox...
                  </Text>
                </View>
              )}

              {syncError ? (
                <View style={styles.errorBanner}>
                  <AlertCircle size={14} color="#e11d48" />
                  <Text style={styles.errorBannerText}>{syncError}</Text>
                </View>
              ) : null}
            </View>

            {/* Filter Tabs */}
            <View style={styles.filterSection}>
              <View style={styles.filterHeader}>
                <Text style={styles.filterTitle}>GetYourGuide Bookings</Text>
                <View style={styles.filterBadge}>
                  <Text style={styles.filterBadgeText}>{filteredBookings.length}</Text>
                </View>
              </View>
              <FilterTabs
                selectedFilter={selectedFilter}
                onSelectFilter={setSelectedFilter}
                counts={counts}
              />
            </View>
          </>
        }
        renderItem={({ item }) => (
          <BookingCard
            booking={item}
            drivers={drivers}
            assignment={assignments[item.referenceNumber]}
            ticketRules={ticketRules}
            reviewers={reviewers}
            reviewerAssignment={reviewerAssignments[item.referenceNumber]}
            onGenerateReview={onGenerateReview}
            onAssignDriver={onAssignDriver}
            onUnassignDriver={onUnassignDriver}
            onAssignReviewer={onAssignReviewer}
            onUnassignReviewer={onUnassignReviewer}
          />
        )}
        ListEmptyComponent={
          isLoading ? (
            <View style={styles.loadingContainer}>
              <ActivityIndicator size="large" color="#4f46e5" />
              <Text style={styles.loadingText}>Fetching live Zoho emails...</Text>
            </View>
          ) : (
            <View style={styles.emptyContainer}>
              <Text style={styles.emptyTitle}>No bookings found</Text>
              <Text style={styles.emptySubtitle}>
                Try adjusting your search query or filter selection.
              </Text>
            </View>
          )
        }
        contentContainerStyle={styles.listContent}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  searchWrapper: {
    paddingHorizontal: 16,
    paddingTop: 8,
    paddingBottom: 4,
    backgroundColor: '#ffffff',
  },
  searchBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#f1f5f9',
    borderRadius: 14,
    paddingHorizontal: 12,
    paddingVertical: 8,
  },
  searchInput: {
    flex: 1,
    fontSize: 13,
    color: '#0f172a',
    fontWeight: '500',
    padding: 0,
  },
  bannerWrapper: {
    marginHorizontal: 16,
    marginBottom: 8,
    gap: 6,
  },
  liveBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#ecfdf5',
    borderWidth: 1,
    borderColor: '#a7f3d0',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 12,
  },
  liveBannerText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#065f46',
  },
  demoBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#fffbeb',
    borderWidth: 1,
    borderColor: '#fde68a',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 12,
  },
  demoBannerText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#92400e',
  },
  errorBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#fff1f2',
    borderWidth: 1,
    borderColor: '#fecdd3',
    paddingHorizontal: 12,
    paddingVertical: 6,
    borderRadius: 10,
  },
  errorBannerText: {
    fontSize: 11,
    color: '#be123c',
    fontWeight: '500',
    flex: 1,
  },
  filterSection: {
    marginBottom: 10,
  },
  filterHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    paddingHorizontal: 16,
    marginBottom: 8,
  },
  filterTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#0f172a',
    letterSpacing: -0.3,
  },
  filterBadge: {
    backgroundColor: '#eef2ff',
    paddingHorizontal: 7,
    paddingVertical: 2,
    borderRadius: 10,
  },
  filterBadgeText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#4f46e5',
  },
  listContent: {
    paddingBottom: 24,
  },
  loadingContainer: {
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  loadingText: {
    fontSize: 13,
    color: '#64748b',
    marginTop: 12,
    fontWeight: '500',
  },
  emptyContainer: {
    padding: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: '#334155',
  },
  emptySubtitle: {
    fontSize: 12,
    color: '#94a3b8',
    marginTop: 4,
    textAlign: 'center',
  },
});

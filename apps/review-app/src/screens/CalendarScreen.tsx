import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  Linking,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import {
  ChevronLeft,
  ChevronRight,
  CalendarDays,
  Clock,
  MapPin,
  User,
  Phone,
  UserCheck,
  XCircle,
  Sparkles,
  ExternalLink,
  Ticket,
} from 'lucide-react-native';
import { BookingItem, Driver, DriverAssignment, TourTicketRule, isBookingReview } from '../types';
import { calculateDriverTourPayout } from '../lib/driverStorage';
import { getBookingTicketDeduction } from '../lib/ticketRulesStorage';

interface CalendarScreenProps {
  bookings: BookingItem[];
  drivers: Driver[];
  assignments: Record<string, DriverAssignment>;
  ticketRules?: TourTicketRule[];
  onAssignDriver: (bookingRef: string, driverId: string, customPayout?: number) => void;
  onUnassignDriver: (bookingRef: string) => void;
  onGenerateReview: (booking: BookingItem) => void;
}

interface DayInfo {
  date: Date;
  dayName: string;
  dayNum: number;
  dateString: string; // YYYY-MM-DD
  isToday: boolean;
  toursCount: number;
}

// Helper to get start of week (Monday)
function getMonday(d: Date): Date {
  const date = new Date(d);
  const day = date.getDay();
  const diff = date.getDate() - day + (day === 0 ? -6 : 1);
  date.setDate(diff);
  date.setHours(0, 0, 0, 0);
  return date;
}

function formatDateString(d: Date): string {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

// Parses booking date string or timestamp into YYYY-MM-DD
function getBookingDateString(b: BookingItem): string | null {
  if (b.timestamp) {
    return formatDateString(new Date(b.timestamp));
  }
  if (b.date && b.date !== 'Upcoming') {
    const parsed = Date.parse(b.date.replace(/at /i, ''));
    if (!isNaN(parsed)) {
      return formatDateString(new Date(parsed));
    }
  }
  return null;
}

function getBookingTime(b: BookingItem): string {
  if (b.date) {
    const timeMatch = b.date.match(/(\d{1,2}:\d{2}\s*(?:AM|PM)?)/i);
    if (timeMatch) return timeMatch[1];
  }
  if (b.timestamp) {
    return new Date(b.timestamp).toLocaleTimeString('en-US', {
      hour: '2-digit',
      minute: '2-digit',
    });
  }
  return 'Flexible';
}

function formatCurrency(val: number): string {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
  }).format(val);
}

export function CalendarScreen({
  bookings,
  drivers,
  assignments,
  ticketRules = [],
  onAssignDriver,
  onUnassignDriver,
  onGenerateReview,
}: CalendarScreenProps) {
  // Current week base date (Monday of active week)
  const [currentMonday, setCurrentMonday] = useState<Date>(() => getMonday(new Date()));
  const [selectedDateString, setSelectedDateString] = useState<string>(() =>
    formatDateString(new Date())
  );
  const [viewMode, setViewMode] = useState<'day' | 'week'>('day');

  // Navigate weeks
  const handlePrevWeek = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const prev = new Date(currentMonday);
    prev.setDate(prev.getDate() - 7);
    setCurrentMonday(prev);
    setSelectedDateString(formatDateString(prev));
  };

  const handleNextWeek = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const next = new Date(currentMonday);
    next.setDate(next.getDate() + 7);
    setCurrentMonday(next);
    setSelectedDateString(formatDateString(next));
  };

  const handleToday = () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    const today = new Date();
    setCurrentMonday(getMonday(today));
    setSelectedDateString(formatDateString(today));
  };

  // Build the 7 days of the current week
  const weekDays = useMemo<DayInfo[]>(() => {
    const days: DayInfo[] = [];
    const todayStr = formatDateString(new Date());

    // Map counts of bookings by date string
    const countsByDate: Record<string, number> = {};
    bookings.forEach((b) => {
      const ds = getBookingDateString(b);
      if (ds) {
        countsByDate[ds] = (countsByDate[ds] || 0) + 1;
      }
    });

    const dayNames = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    for (let i = 0; i < 7; i++) {
      const d = new Date(currentMonday);
      d.setDate(d.getDate() + i);
      const ds = formatDateString(d);
      days.push({
        date: d,
        dayName: dayNames[i],
        dayNum: d.getDate(),
        dateString: ds,
        isToday: ds === todayStr,
        toursCount: countsByDate[ds] || 0,
      });
    }
    return days;
  }, [currentMonday, bookings]);

  // Week range label e.g. "Sep 21 – Sep 27, 2026"
  const weekRangeLabel = useMemo(() => {
    const sunday = new Date(currentMonday);
    sunday.setDate(sunday.getDate() + 6);
    const startMonth = currentMonday.toLocaleString('en-US', { month: 'short' });
    const endMonth = sunday.toLocaleString('en-US', { month: 'short' });
    const startDay = currentMonday.getDate();
    const endDay = sunday.getDate();
    const year = sunday.getFullYear();

    if (startMonth === endMonth) {
      return `${startMonth} ${startDay} – ${endDay}, ${year}`;
    }
    return `${startMonth} ${startDay} – ${endMonth} ${endDay}, ${year}`;
  }, [currentMonday]);

  // Filter bookings for the current view
  const weekDateStrings = useMemo(
    () => new Set(weekDays.map((w) => w.dateString)),
    [weekDays]
  );

  const toursThisWeek = useMemo(() => {
    return bookings.filter((b) => {
      const ds = getBookingDateString(b);
      return ds && weekDateStrings.has(ds);
    });
  }, [bookings, weekDateStrings]);

  const displayedTours = useMemo(() => {
    if (viewMode === 'day') {
      return bookings.filter((b) => getBookingDateString(b) === selectedDateString);
    }
    // 'week' view: sorted chronologically
    return [...toursThisWeek].sort(
      (a, b) => (a.timestamp || 0) - (b.timestamp || 0)
    );
  }, [bookings, selectedDateString, viewMode, toursThisWeek]);

  // Week overview metrics (strictly excluding cancelled tours!)
  const weekStats = useMemo(() => {
    let activeTours = 0;
    let netPayout = 0;
    let ticketCosts = 0;
    let assignedCount = 0;
    let cancelledCount = 0;

    toursThisWeek.forEach((b) => {
      if (b.status === 'cancelled') {
        cancelledCount++;
        return;
      }
      activeTours++;
      const price = b.priceAmount || parseFloat((b.price || '').replace(/[^0-9.]/g, '')) || 0;
      const tourNet = price * 0.7; // 70% net
      netPayout += tourNet;
      const ticketInfo = getBookingTicketDeduction(b, ticketRules);
      ticketCosts += ticketInfo.totalCost;
      if (assignments[b.referenceNumber]) {
        assignedCount++;
      }
    });

    const netProfit = Math.max(0, netPayout - ticketCosts);

    return {
      activeTours,
      netPayout,
      ticketCosts,
      netProfit,
      assignedCount,
      cancelledCount,
    };
  }, [toursThisWeek, assignments, ticketRules]);

  const selectedDayInfo = weekDays.find((d) => d.dateString === selectedDateString);

  return (
    <View style={styles.container}>
      {/* Top Week Switcher Bar */}
      <View style={styles.navBar}>
        <TouchableOpacity
          style={styles.navArrowBtn}
          onPress={handlePrevWeek}
          activeOpacity={0.7}
        >
          <ChevronLeft size={20} color="#1e293b" />
        </TouchableOpacity>

        <View style={styles.navCenter}>
          <Text style={styles.weekRangeText}>{weekRangeLabel}</Text>
          <TouchableOpacity
            style={styles.todayBtn}
            onPress={handleToday}
            activeOpacity={0.7}
          >
            <Text style={styles.todayBtnText}>Today</Text>
          </TouchableOpacity>
        </View>

        <TouchableOpacity
          style={styles.navArrowBtn}
          onPress={handleNextWeek}
          activeOpacity={0.7}
        >
          <ChevronRight size={20} color="#1e293b" />
        </TouchableOpacity>
      </View>

      {/* 7-Day Strip */}
      <View style={styles.weekStrip}>
        {weekDays.map((d) => {
          const isSelected = d.dateString === selectedDateString;
          return (
            <TouchableOpacity
              key={d.dateString}
              style={[
                styles.dayPill,
                isSelected && styles.dayPillSelected,
                d.isToday && !isSelected && styles.dayPillToday,
              ]}
              onPress={() => {
                Haptics.selectionAsync();
                setSelectedDateString(d.dateString);
                setViewMode('day');
              }}
              activeOpacity={0.8}
            >
              <Text
                style={[
                  styles.dayNameText,
                  isSelected && styles.dayTextSelected,
                  d.isToday && !isSelected && styles.dayNameToday,
                ]}
              >
                {d.dayName}
              </Text>
              <Text
                style={[
                  styles.dayNumText,
                  isSelected && styles.dayTextSelected,
                  d.isToday && !isSelected && styles.dayNumToday,
                ]}
              >
                {d.dayNum}
              </Text>

              {/* Tour indicator dot or badge */}
              {d.toursCount > 0 ? (
                <View
                  style={[
                    styles.tourBadge,
                    isSelected && styles.tourBadgeSelected,
                  ]}
                >
                  <Text
                    style={[
                      styles.tourBadgeText,
                      isSelected && styles.tourBadgeTextSelected,
                    ]}
                  >
                    {d.toursCount}
                  </Text>
                </View>
              ) : (
                <View style={styles.emptyDot} />
              )}
            </TouchableOpacity>
          );
        })}
      </View>

      {/* Week Metrics Banner */}
      <View style={styles.metricsBanner}>
        <View style={styles.metricItem}>
          <Text style={styles.metricVal}>{weekStats.activeTours}</Text>
          <Text style={styles.metricLabel}>Tours this week</Text>
        </View>
        <View style={styles.metricDivider} />
        <View style={styles.metricItem}>
          <Text style={[styles.metricVal, styles.payoutVal]}>
            {formatCurrency(weekStats.ticketCosts > 0 ? weekStats.netProfit : weekStats.netPayout)}
          </Text>
          <Text style={styles.metricLabel}>
            {weekStats.ticketCosts > 0 ? 'Est. Net Profit' : 'Est. Net Payout'}
          </Text>
          {weekStats.ticketCosts > 0 && (
            <Text style={styles.metricTicketSub}>
              -€{weekStats.ticketCosts.toFixed(0)} tickets deducted
            </Text>
          )}
        </View>
        <View style={styles.metricDivider} />
        <View style={styles.metricItem}>
          <Text style={styles.metricVal}>
            {weekStats.assignedCount}/{weekStats.activeTours}
          </Text>
          <Text style={styles.metricLabel}>Drivers Assigned</Text>
        </View>
      </View>

      {/* Mode Switcher & Date Header */}
      <View style={styles.sectionHeader}>
        <View>
          <Text style={styles.sectionTitle}>
            {viewMode === 'day'
              ? `${selectedDayInfo?.date.toLocaleDateString('en-US', {
                  weekday: 'long',
                  month: 'short',
                  day: 'numeric',
                }) || 'Day View'}`
              : `Full Week Agenda (${displayedTours.length} tours)`}
          </Text>
          <Text style={styles.sectionSubtitle}>
            {viewMode === 'day'
              ? `${displayedTours.length} scheduled ${
                  displayedTours.length === 1 ? 'tour' : 'tours'
                }`
              : 'Monday to Sunday overview'}
          </Text>
        </View>

        {/* View Mode Toggle Buttons */}
        <View style={styles.toggleGroup}>
          <TouchableOpacity
            style={[
              styles.toggleBtn,
              viewMode === 'day' && styles.toggleBtnActive,
            ]}
            onPress={() => {
              Haptics.selectionAsync();
              setViewMode('day');
            }}
          >
            <Text
              style={[
                styles.toggleBtnText,
                viewMode === 'day' && styles.toggleBtnTextActive,
              ]}
            >
              Day
            </Text>
          </TouchableOpacity>
          <TouchableOpacity
            style={[
              styles.toggleBtn,
              viewMode === 'week' && styles.toggleBtnActive,
            ]}
            onPress={() => {
              Haptics.selectionAsync();
              setViewMode('week');
            }}
          >
            <Text
              style={[
                styles.toggleBtnText,
                viewMode === 'week' && styles.toggleBtnTextActive,
              ]}
            >
              Agenda
            </Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* Tours List */}
      <FlatList
        data={displayedTours}
        keyExtractor={(item) => item.id || item.referenceNumber}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
        renderItem={({ item }) => {
          const isCancelled = item.status === 'cancelled';
          const time = getBookingTime(item);
          const assignment = assignments[item.referenceNumber];
          const assignedDriver = assignment
            ? drivers.find((d) => d.id === assignment.driverId)
            : undefined;
          const driverPayout = assignedDriver
            ? calculateDriverTourPayout(item, assignedDriver, assignment?.customPayoutAmount)
            : 0;
          const ticketInfo = getBookingTicketDeduction(item, ticketRules);
          const isReview = isBookingReview(item);

          return (
            <View style={[styles.tourCard, isCancelled && styles.tourCardCancelled]}>
              {/* Tour Header with Time and Status Badges */}
              <View style={styles.tourCardHeader}>
                <View style={styles.timeBadge}>
                  <Clock size={12} color="#3b82f6" />
                  <Text style={styles.timeBadgeText}>{time}</Text>
                </View>

                <View style={styles.headerBadges}>
                  {isCancelled ? (
                    <View style={styles.cancelledBadge}>
                      <XCircle size={11} color="#ffffff" />
                      <Text style={styles.cancelledBadgeText}>CANCELLED</Text>
                    </View>
                  ) : (
                    <>
                      {ticketInfo.hasDeduction && (
                        <View style={styles.calendarTicketBadge}>
                          <Ticket size={10} color="#b45309" />
                          <Text style={styles.calendarTicketText}>
                            -€{ticketInfo.totalCost.toFixed(0)} tix
                          </Text>
                        </View>
                      )}
                      <View style={styles.confirmedBadge}>
                        <Text style={styles.confirmedBadgeText}>
                          {item.price || 'Confirmed'}
                        </Text>
                      </View>
                    </>
                  )}
                </View>
              </View>

              {/* Tour Title */}
              <Text
                style={[
                  styles.tourTitle,
                  isCancelled && styles.tourTitleCancelled,
                ]}
                numberOfLines={2}
              >
                {item.tourTitle}
              </Text>

              {/* Booking Reference */}
              <Text style={styles.refText}>Ref: {item.referenceNumber}</Text>

              {/* Auto Ticket Deduction info */}
              {!isCancelled && ticketInfo.hasDeduction && (
                <View style={styles.calendarTicketRow}>
                  <Ticket size={11} color="#b45309" />
                  <Text style={styles.calendarTicketRowText}>
                    Tickets: -€{ticketInfo.totalCost.toFixed(2)} ({ticketInfo.passengerCount} pax) · Profit: €{ticketInfo.netProfitAfterTickets.toFixed(2)}
                  </Text>
                </View>
              )}

              {/* Details Rows */}
              <View style={styles.cardDetails}>
                <View style={styles.detailRow}>
                  <User size={12} color="#64748b" />
                  <Text style={styles.detailText} numberOfLines={1}>
                    {item.customerName || 'Customer'}
                    {item.participants ? ` (${item.participants})` : ''}
                  </Text>
                </View>

                {item.customerPhone ? (
                  <TouchableOpacity
                    style={styles.detailRow}
                    onPress={() =>
                      Linking.openURL(`tel:${item.customerPhone.replace(/\s+/g, '')}`)
                    }
                  >
                    <Phone size={12} color="#2563eb" />
                    <Text style={[styles.detailText, styles.linkText]} numberOfLines={1}>
                      {item.customerPhone}
                    </Text>
                  </TouchableOpacity>
                ) : null}

                {item.pickup ? (
                  <TouchableOpacity
                    style={styles.detailRow}
                    onPress={() => {
                      if (item.mapsUrl) {
                        Linking.openURL(item.mapsUrl);
                      } else {
                        Linking.openURL(
                          `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(
                            item.pickup
                          )}`
                        );
                      }
                    }}
                  >
                    <MapPin size={12} color="#2563eb" />
                    <Text
                      style={[styles.detailText, styles.linkText]}
                      numberOfLines={1}
                    >
                      {item.pickup}
                    </Text>
                    <ExternalLink size={10} color="#2563eb" />
                  </TouchableOpacity>
                ) : null}
              </View>

              {/* Driver & Action Bar */}
              <View style={styles.cardFooter}>
                <View style={styles.driverInfo}>
                  <UserCheck
                    size={13}
                    color={assignedDriver ? '#2563eb' : '#94a3b8'}
                  />
                  {assignedDriver ? (
                    <View style={styles.driverPill}>
                      <View
                        style={[
                          styles.driverDot,
                          { backgroundColor: assignedDriver.color || '#3b82f6' },
                        ]}
                      />
                      <Text style={styles.driverPillText}>
                        {assignedDriver.name}
                      </Text>
                      {!isCancelled && (
                        <Text style={styles.driverPayoutCut}>
                          (€{driverPayout.toFixed(2)})
                        </Text>
                      )}
                    </View>
                  ) : (
                    <Text style={styles.noDriverText}>No driver</Text>
                  )}
                </View>

                {!isCancelled && isReview && (
                  <TouchableOpacity
                    style={styles.reviewStudioBtn}
                    onPress={() => onGenerateReview(item)}
                    activeOpacity={0.7}
                  >
                    <Sparkles size={11} color="#4f46e5" />
                    <Text style={styles.reviewStudioBtnText}>Studio</Text>
                  </TouchableOpacity>
                )}
              </View>
            </View>
          );
        }}
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <CalendarDays size={42} color="#cbd5e1" />
            <Text style={styles.emptyStateTitle}>No tours on this date</Text>
            <Text style={styles.emptyStateSub}>
              Select another day from the strip above or view the week agenda.
            </Text>
          </View>
        }
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  navBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
    backgroundColor: '#ffffff',
  },
  navArrowBtn: {
    width: 36,
    height: 36,
    borderRadius: 10,
    backgroundColor: '#f1f5f9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  navCenter: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  weekRangeText: {
    fontSize: 15,
    fontWeight: '800',
    color: '#0f172a',
    letterSpacing: -0.3,
  },
  todayBtn: {
    backgroundColor: '#eef2ff',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
  },
  todayBtnText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#4f46e5',
  },
  weekStrip: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 12,
    paddingVertical: 10,
    backgroundColor: '#ffffff',
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  dayPill: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: 8,
    marginHorizontal: 2,
    borderRadius: 14,
    backgroundColor: '#f8fafc',
  },
  dayPillSelected: {
    backgroundColor: '#4f46e5',
  },
  dayPillToday: {
    borderWidth: 1.5,
    borderColor: '#4f46e5',
    backgroundColor: '#ffffff',
  },
  dayNameText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#64748b',
    marginBottom: 4,
  },
  dayNumText: {
    fontSize: 15,
    fontWeight: '900',
    color: '#1e293b',
    marginBottom: 4,
  },
  dayNameToday: {
    color: '#4f46e5',
  },
  dayNumToday: {
    color: '#4f46e5',
  },
  dayTextSelected: {
    color: '#ffffff',
  },
  tourBadge: {
    minWidth: 16,
    height: 16,
    borderRadius: 8,
    backgroundColor: '#e0e7ff',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 4,
  },
  tourBadgeSelected: {
    backgroundColor: '#ffffff',
  },
  tourBadgeText: {
    fontSize: 9,
    fontWeight: '800',
    color: '#4338ca',
  },
  tourBadgeTextSelected: {
    color: '#4f46e5',
  },
  emptyDot: {
    width: 4,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#e2e8f0',
  },
  metricsBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-around',
    backgroundColor: '#ffffff',
    marginHorizontal: 16,
    marginTop: 10,
    paddingVertical: 10,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  metricItem: {
    alignItems: 'center',
    flex: 1,
  },
  metricDivider: {
    width: 1,
    height: 24,
    backgroundColor: '#f1f5f9',
  },
  metricVal: {
    fontSize: 14,
    fontWeight: '800',
    color: '#0f172a',
  },
  payoutVal: {
    color: '#059669',
  },
  metricLabel: {
    fontSize: 10,
    color: '#64748b',
    marginTop: 2,
  },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    marginTop: 14,
    marginBottom: 8,
  },
  sectionTitle: {
    fontSize: 14,
    fontWeight: '800',
    color: '#0f172a',
  },
  sectionSubtitle: {
    fontSize: 11,
    color: '#64748b',
  },
  toggleGroup: {
    flexDirection: 'row',
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    padding: 2,
  },
  toggleBtn: {
    paddingHorizontal: 10,
    paddingVertical: 4,
    borderRadius: 6,
  },
  toggleBtnActive: {
    backgroundColor: '#ffffff',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.1,
    shadowRadius: 2,
  },
  toggleBtnText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#64748b',
  },
  toggleBtnTextActive: {
    color: '#4f46e5',
    fontWeight: '800',
  },
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 24,
  },
  tourCard: {
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 5,
  },
  tourCardCancelled: {
    backgroundColor: '#fef2f2',
    borderColor: '#fecaca',
  },
  tourCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 8,
  },
  timeBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#eff6ff',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
  },
  timeBadgeText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#2563eb',
  },
  headerBadges: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  confirmedBadge: {
    backgroundColor: '#ecfdf5',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
  },
  confirmedBadgeText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#059669',
  },
  cancelledBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: '#dc2626',
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: 6,
  },
  cancelledBadgeText: {
    fontSize: 9,
    fontWeight: '900',
    color: '#ffffff',
  },
  tourTitle: {
    fontSize: 14,
    fontWeight: '800',
    color: '#0f172a',
    lineHeight: 19,
    marginBottom: 2,
  },
  tourTitleCancelled: {
    color: '#64748b',
  },
  refText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#94a3b8',
    fontFamily: 'Courier',
    marginBottom: 8,
  },
  cardDetails: {
    gap: 4,
    backgroundColor: '#f8fafc',
    padding: 8,
    borderRadius: 10,
    marginBottom: 8,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  detailText: {
    fontSize: 11,
    color: '#475569',
    fontWeight: '500',
    flex: 1,
  },
  linkText: {
    color: '#2563eb',
    fontWeight: '600',
  },
  cardFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: 4,
  },
  driverInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  driverPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  driverDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
  },
  driverPillText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#1e293b',
  },
  driverPayoutCut: {
    fontSize: 11,
    fontWeight: '800',
    color: '#059669',
  },
  noDriverText: {
    fontSize: 11,
    color: '#94a3b8',
    fontStyle: 'italic',
  },
  reviewStudioBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#eef2ff',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  reviewStudioBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#4f46e5',
  },
  emptyState: {
    paddingVertical: 40,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyStateTitle: {
    fontSize: 15,
    fontWeight: '800',
    color: '#334155',
    marginTop: 12,
  },
  emptyStateSub: {
    fontSize: 12,
    color: '#94a3b8',
    textAlign: 'center',
    maxWidth: 240,
    marginTop: 4,
  },
  metricTicketSub: {
    fontSize: 9,
    color: '#b45309',
    fontWeight: '700',
    marginTop: 1,
  },
  calendarTicketBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: '#fef3c7',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#fde68a',
  },
  calendarTicketText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#b45309',
  },
  calendarTicketRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: '#fffbeb',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    marginTop: 4,
    marginBottom: 4,
    borderWidth: 1,
    borderColor: '#fde68a',
  },
  calendarTicketRowText: {
    fontSize: 10,
    fontWeight: '600',
    color: '#92400e',
  },
});

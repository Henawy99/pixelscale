import React, { useState } from 'react';
import { View, Text, StyleSheet, TouchableOpacity, Modal, FlatList } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { Wallet, ChevronDown, Check, TrendingUp, Briefcase, Star, Ticket } from 'lucide-react-native';
import * as Haptics from 'expo-haptics';
import { BookingItem, TourTicketRule, isBookingReview, getNumericPrice } from '../types';
import { getBookingTicketDeduction } from '../lib/ticketRulesStorage';

interface RevenueCardProps {
  bookings: BookingItem[];
  ticketRules?: TourTicketRule[];
}

function getMonthYear(b: BookingItem): string {
  if (b.date && b.date !== 'Upcoming') {
    const match = b.date.match(/([A-Za-z]+)\s+\d{1,2},\s+(\d{4})/);
    if (match) return `${match[1]} ${match[2]}`;
  }
  if (b.timestamp) {
    const d = new Date(b.timestamp);
    return d.toLocaleString('en-US', { month: 'long', year: 'numeric' });
  }
  return 'Other';
}

function formatEur(num: number): string {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(num);
}

export function RevenueCard({ bookings, ticketRules = [] }: RevenueCardProps) {
  const [selectedMonth, setSelectedMonth] = useState('September 2026');
  const [modalVisible, setModalVisible] = useState(false);

  // Group by month
  const monthlyData: Record<
    string,
    {
      gross: number;
      net: number;
      fee: number;
      ticketCosts: number;
      profit: number;
      normalGross: number;
      normalNet: number;
      normalFee: number;
      normalCount: number;
      reviewGross: number;
      reviewNet: number;
      reviewFee: number;
      reviewCount: number;
      count: number;
    }
  > = {};

  bookings.forEach((b) => {
    if (b.status === 'cancelled') return;
    const m = getMonthYear(b);
    if (!monthlyData[m]) {
      monthlyData[m] = {
        gross: 0,
        net: 0,
        fee: 0,
        ticketCosts: 0,
        profit: 0,
        normalGross: 0,
        normalNet: 0,
        normalFee: 0,
        normalCount: 0,
        reviewGross: 0,
        reviewNet: 0,
        reviewFee: 0,
        reviewCount: 0,
        count: 0,
      };
    }

    const price = getNumericPrice(b);
    const fee = price * 0.3;
    const net = price * 0.7;
    const isReview = isBookingReview(b);

    const ticketResult = getBookingTicketDeduction(b, ticketRules);
    const ticketCost = ticketResult.totalCost;
    const profit = Math.max(0, net - ticketCost);

    monthlyData[m].gross += price;
    monthlyData[m].fee += fee;
    monthlyData[m].net += net;
    monthlyData[m].ticketCosts += ticketCost;
    monthlyData[m].profit += profit;
    monthlyData[m].count += 1;

    if (isReview) {
      monthlyData[m].reviewGross += price;
      monthlyData[m].reviewFee += fee;
      monthlyData[m].reviewNet += net;
      monthlyData[m].reviewCount += 1;
    } else {
      monthlyData[m].normalGross += price;
      monthlyData[m].normalFee += fee;
      monthlyData[m].normalNet += net;
      monthlyData[m].normalCount += 1;
    }
  });

  const availableMonths = Object.keys(monthlyData).sort((a, b) => {
    if (a.includes('September')) return -1;
    if (b.includes('September')) return 1;
    return a.localeCompare(b);
  });

  const allMonthsList = [...availableMonths, 'All Time'];

  const activeStats =
    selectedMonth === 'All Time'
      ? Object.values(monthlyData).reduce(
          (acc, cur) => ({
            gross: acc.gross + cur.gross,
            net: acc.net + cur.net,
            fee: acc.fee + cur.fee,
            ticketCosts: acc.ticketCosts + cur.ticketCosts,
            profit: acc.profit + cur.profit,
            normalGross: acc.normalGross + cur.normalGross,
            normalNet: acc.normalNet + cur.normalNet,
            normalFee: acc.normalFee + cur.normalFee,
            normalCount: acc.normalCount + cur.normalCount,
            reviewGross: acc.reviewGross + cur.reviewGross,
            reviewNet: acc.reviewNet + cur.reviewNet,
            reviewFee: acc.reviewFee + cur.reviewFee,
            reviewCount: acc.reviewCount + cur.reviewCount,
            count: acc.count + cur.count,
          }),
          {
            gross: 0,
            net: 0,
            fee: 0,
            ticketCosts: 0,
            profit: 0,
            normalGross: 0,
            normalNet: 0,
            normalFee: 0,
            normalCount: 0,
            reviewGross: 0,
            reviewNet: 0,
            reviewFee: 0,
            reviewCount: 0,
            count: 0,
          }
        )
      : monthlyData[selectedMonth] || {
          gross: 0,
          net: 0,
          fee: 0,
          ticketCosts: 0,
          profit: 0,
          normalGross: 0,
          normalNet: 0,
          normalFee: 0,
          normalCount: 0,
          reviewGross: 0,
          reviewNet: 0,
          reviewFee: 0,
          reviewCount: 0,
          count: 0,
        };

  const handleSelectMonth = (m: string) => {
    Haptics.selectionAsync();
    setSelectedMonth(m);
    setModalVisible(false);
  };

  const hasTicketCosts = activeStats.ticketCosts > 0;

  return (
    <View style={styles.cardWrapper}>
      <LinearGradient
        colors={['#1e1b4b', '#312e81', '#4338ca']}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.gradientCard}
      >
        {/* Header row */}
        <View style={styles.cardHeader}>
          <View style={styles.titleGroup}>
            <View style={styles.walletIcon}>
              <Wallet size={16} color="#34d399" />
            </View>
            <View>
              <Text style={styles.cardHeaderTitle}>MONTHLY REVENUE & NET</Text>
              <Text style={styles.cardHeaderSub}>
                {hasTicketCosts
                  ? '30% GYG fee & ticket costs deducted'
                  : '30% GYG commission deducted'}
              </Text>
            </View>
          </View>

          {/* Month selector pill */}
          <TouchableOpacity
            style={styles.monthSelector}
            onPress={() => {
              Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
              setModalVisible(true);
            }}
            activeOpacity={0.8}
          >
            <Text style={styles.monthSelectorText}>{selectedMonth}</Text>
            <ChevronDown size={14} color="#e0e7ff" />
          </TouchableOpacity>
        </View>

        {/* Payout Display */}
        <View style={styles.payoutContainer}>
          <Text style={styles.payoutLabel}>
            {hasTicketCosts
              ? 'ESTIMATED NET OPERATOR PROFIT'
              : 'ESTIMATED NET PAYOUT (70%)'}
          </Text>
          <View style={styles.amountRow}>
            <Text style={styles.payoutAmount}>
              {formatEur(hasTicketCosts ? activeStats.profit : activeStats.net)}
            </Text>
            <View style={styles.countBadge}>
              <TrendingUp size={12} color="#34d399" />
              <Text style={styles.countBadgeText}>{activeStats.count} bookings</Text>
            </View>
          </View>

          {hasTicketCosts && (
            <Text style={styles.payoutSubBreakdown}>
              GYG Net (70%): {formatEur(activeStats.net)} · Tickets: -
              {formatEur(activeStats.ticketCosts)}
            </Text>
          )}
        </View>

        {/* Top breakdown (Gross, Fee & Ticket Costs) */}
        <View style={styles.topBreakdownRow}>
          <View style={styles.topStatBox}>
            <Text style={styles.statBoxLabel}>Gross Revenue</Text>
            <Text style={styles.statBoxValue}>{formatEur(activeStats.gross)}</Text>
          </View>

          <View style={[styles.topStatBox, styles.statBoxFee]}>
            <Text style={[styles.statBoxLabel, styles.feeText]}>GYG Fee (30%)</Text>
            <Text style={[styles.statBoxValue, styles.feeText]}>
              -{formatEur(activeStats.fee)}
            </Text>
          </View>

          {hasTicketCosts && (
            <View style={[styles.topStatBox, styles.statBoxTickets]}>
              <View style={styles.ticketBoxHeader}>
                <Ticket size={11} color="#fed7aa" />
                <Text style={[styles.statBoxLabel, styles.ticketsText]}>
                  Tickets
                </Text>
              </View>
              <Text style={[styles.statBoxValue, styles.ticketsText]}>
                -{formatEur(activeStats.ticketCosts)}
              </Text>
            </View>
          )}
        </View>

        {/* Bottom Tour Categorization (Normal vs Review) */}
        <View style={styles.categoriesRow}>
          {/* Normal Tours */}
          <View style={styles.catCard}>
            <View style={styles.catHeader}>
              <Briefcase size={14} color="#93c5fd" />
              <Text style={styles.catTitle}>Normal Tours</Text>
              <Text style={styles.catSub}>≥€30</Text>
            </View>
            <Text style={styles.catNet}>{formatEur(activeStats.normalNet)} net</Text>
            <Text style={styles.catDetails}>
              Gross: {formatEur(activeStats.normalGross)}
            </Text>
            <Text style={styles.catDetailsFee}>
              30% fee: -{formatEur(activeStats.normalFee)}
            </Text>
            <Text style={styles.catCount}>{activeStats.normalCount} tours</Text>
          </View>

          {/* Review Bookings */}
          <View style={styles.catCard}>
            <View style={styles.catHeader}>
              <Star size={14} color="#fbbf24" fill="#fbbf24" />
              <Text style={styles.catTitle}>Review Bookings</Text>
              <Text style={styles.catSub}>&lt;€30</Text>
            </View>
            <Text style={[styles.catNet, styles.reviewNetText]}>
              {formatEur(activeStats.reviewNet)} net
            </Text>
            <Text style={styles.catDetails}>
              Gross: {formatEur(activeStats.reviewGross)}
            </Text>
            <Text style={styles.catDetailsFee}>
              30% fee: -{formatEur(activeStats.reviewFee)}
            </Text>
            <Text style={styles.catCount}>{activeStats.reviewCount} bookings</Text>
          </View>
        </View>
      </LinearGradient>

      {/* Month Selection Modal */}
      <Modal visible={modalVisible} transparent animationType="fade">
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setModalVisible(false)}
        >
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Select Revenue Month</Text>
            <FlatList
              data={allMonthsList}
              keyExtractor={(item) => item}
              renderItem={({ item }) => {
                const isSelected = item === selectedMonth;
                return (
                  <TouchableOpacity
                    style={[styles.modalItem, isSelected && styles.modalItemSelected]}
                    onPress={() => handleSelectMonth(item)}
                  >
                    <Text
                      style={[
                        styles.modalItemText,
                        isSelected && styles.modalItemTextSelected,
                      ]}
                    >
                      {item}
                    </Text>
                    {isSelected && <Check size={18} color="#4f46e5" />}
                  </TouchableOpacity>
                );
              }}
            />
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  cardWrapper: {
    marginHorizontal: 16,
    marginVertical: 12,
  },
  gradientCard: {
    borderRadius: 24,
    padding: 18,
    shadowColor: '#312e81',
    shadowOffset: { width: 0, height: 8 },
    shadowOpacity: 0.25,
    shadowRadius: 16,
  },
  cardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  titleGroup: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  walletIcon: {
    width: 28,
    height: 28,
    borderRadius: 8,
    backgroundColor: 'rgba(255,255,255,0.12)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  cardHeaderTitle: {
    fontSize: 10,
    fontWeight: '800',
    color: '#c7d2fe',
    letterSpacing: 0.8,
  },
  cardHeaderSub: {
    fontSize: 10,
    color: 'rgba(224, 231, 255, 0.7)',
  },
  monthSelector: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: 'rgba(255,255,255,0.16)',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.2)',
  },
  monthSelectorText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#ffffff',
  },
  payoutContainer: {
    marginBottom: 16,
  },
  payoutLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#34d399',
    letterSpacing: 0.5,
    marginBottom: 4,
  },
  amountRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    justifyContent: 'space-between',
  },
  payoutAmount: {
    fontSize: 32,
    fontWeight: '900',
    color: '#ffffff',
    letterSpacing: -0.5,
  },
  payoutSubBreakdown: {
    fontSize: 11,
    fontWeight: '600',
    color: 'rgba(224, 231, 255, 0.85)',
    marginTop: 4,
  },
  countBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(16, 185, 129, 0.16)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 12,
  },
  countBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#34d399',
  },
  topBreakdownRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 14,
  },
  topStatBox: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: 14,
    padding: 9,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  statBoxFee: {
    backgroundColor: 'rgba(244, 63, 94, 0.12)',
    borderColor: 'rgba(244, 63, 94, 0.2)',
  },
  statBoxTickets: {
    backgroundColor: 'rgba(249, 115, 22, 0.15)',
    borderColor: 'rgba(249, 115, 22, 0.3)',
  },
  ticketBoxHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    marginBottom: 2,
  },
  statBoxLabel: {
    fontSize: 10,
    color: '#c7d2fe',
    marginBottom: 2,
    fontWeight: '600',
  },
  feeText: {
    color: '#fda4af',
  },
  ticketsText: {
    color: '#fed7aa',
  },
  statBoxValue: {
    fontSize: 13,
    fontWeight: '800',
    color: '#ffffff',
  },
  categoriesRow: {
    flexDirection: 'row',
    gap: 10,
  },
  catCard: {
    flex: 1,
    backgroundColor: 'rgba(255,255,255,0.08)',
    borderRadius: 14,
    padding: 10,
    borderWidth: 1,
    borderColor: 'rgba(255,255,255,0.1)',
  },
  catHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginBottom: 4,
  },
  catTitle: {
    fontSize: 11,
    fontWeight: '700',
    color: '#ffffff',
    flex: 1,
  },
  catSub: {
    fontSize: 9,
    color: '#c7d2fe',
    fontWeight: '600',
  },
  catNet: {
    fontSize: 14,
    fontWeight: '800',
    color: '#93c5fd',
    marginBottom: 2,
  },
  reviewNetText: {
    color: '#fde047',
  },
  catDetails: {
    fontSize: 10,
    color: 'rgba(255,255,255,0.7)',
  },
  catDetailsFee: {
    fontSize: 9,
    color: '#fda4af',
    marginBottom: 4,
  },
  catCount: {
    fontSize: 10,
    color: '#cbd5e1',
    fontWeight: '600',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  modalContent: {
    width: '100%',
    maxWidth: 320,
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 18,
    maxHeight: 400,
  },
  modalTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#0f172a',
    marginBottom: 12,
  },
  modalItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 12,
    paddingHorizontal: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  modalItemSelected: {
    backgroundColor: '#eef2ff',
    borderRadius: 10,
  },
  modalItemText: {
    fontSize: 14,
    color: '#334155',
    fontWeight: '600',
  },
  modalItemTextSelected: {
    color: '#4f46e5',
    fontWeight: '800',
  },
});

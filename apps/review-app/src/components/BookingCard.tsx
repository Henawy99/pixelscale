import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  Modal,
  FlatList,
  TextInput,
  Linking,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import {
  Calendar,
  MapPin,
  User,
  Phone,
  Copy,
  Check,
  Sparkles,
  Star,
  Flame,
  XCircle,
  UserCheck,
  Plus,
  X,
  ExternalLink,
} from 'lucide-react-native';
import { BookingItem, Driver, DriverAssignment, TourTicketRule } from '../types';
import { calculateDriverTourPayout } from '../lib/driverStorage';
import { getBookingTicketDeduction } from '../lib/ticketRulesStorage';
import { Ticket } from 'lucide-react-native';

interface BookingCardProps {
  booking: BookingItem;
  drivers?: Driver[];
  assignment?: DriverAssignment;
  ticketRules?: TourTicketRule[];
  onGenerateReview: (booking: BookingItem) => void;
  onAssignDriver?: (bookingRef: string, driverId: string, customPayout?: number) => void;
  onUnassignDriver?: (bookingRef: string) => void;
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

export function BookingCard({
  booking,
  drivers = [],
  assignment,
  ticketRules = [],
  onGenerateReview,
  onAssignDriver,
  onUnassignDriver,
}: BookingCardProps) {
  const [copied, setCopied] = useState(false);
  const [driverModalVisible, setDriverModalVisible] = useState(false);
  const [customPayoutText, setCustomPayoutText] = useState(
    assignment?.customPayoutAmount ? String(assignment.customPayoutAmount) : ''
  );

  const isCancelled = booking.status === 'cancelled';
  const isReview = isBookingReview(booking);
  const priceNum = getNumericPrice(booking);

  // Tour Ticket Cost Auto-Deduction
  const ticketInfo = getBookingTicketDeduction(booking, ticketRules);

  // Assigned driver object
  const assignedDriver = assignment
    ? drivers.find((d) => d.id === assignment.driverId)
    : undefined;

  const driverPayout = assignedDriver
    ? calculateDriverTourPayout(booking, assignedDriver, assignment?.customPayoutAmount)
    : 0;

  const handleCopyRef = async () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await Clipboard.setStringAsync(booking.referenceNumber);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const handleGenerate = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onGenerateReview(booking);
  };

  const handleSelectDriver = (driver: Driver) => {
    Haptics.selectionAsync();
    const customNum = parseFloat(customPayoutText.replace(',', '.'));
    const customPayout = !isNaN(customNum) && customNum > 0 ? customNum : undefined;
    if (onAssignDriver) {
      onAssignDriver(booking.referenceNumber, driver.id, customPayout);
    }
    setDriverModalVisible(false);
  };

  const handleRemoveAssignment = () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    if (onUnassignDriver) {
      onUnassignDriver(booking.referenceNumber);
    }
    setDriverModalVisible(false);
  };

  const openGoogleMaps = () => {
    if (booking.mapsUrl) {
      Linking.openURL(booking.mapsUrl);
    } else if (booking.pickup) {
      Linking.openURL(`https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(booking.pickup)}`);
    }
  };

  const callCustomer = () => {
    if (booking.customerPhone) {
      Linking.openURL(`tel:${booking.customerPhone.replace(/\s+/g, '')}`);
    }
  };

  return (
    <View style={[styles.card, isCancelled && styles.cardCancelled]}>
      {/* Top Header: Ref Badge + Status / Price Badges */}
      <View style={styles.headerRow}>
        <TouchableOpacity
          style={styles.refBadge}
          onPress={handleCopyRef}
          activeOpacity={0.7}
        >
          <Text style={styles.refText}>{booking.referenceNumber}</Text>
          {copied ? (
            <Check size={12} color="#10b981" />
          ) : (
            <Copy size={12} color="#64748b" />
          )}
        </TouchableOpacity>

        <View style={styles.badgesGroup}>
          {isCancelled ? (
            <View style={styles.cancelledBadge}>
              <XCircle size={12} color="#ffffff" />
              <Text style={styles.cancelledBadgeText}>CANCELLED</Text>
            </View>
          ) : (
            <>
              {isReview && (
                <View style={styles.reviewBadge}>
                  <Star size={11} color="#b45309" fill="#b45309" />
                  <Text style={styles.reviewBadgeText}>Review (&lt;€30)</Text>
                </View>
              )}

              {ticketInfo.hasDeduction && (
                <View style={styles.ticketBadge}>
                  <Ticket size={11} color="#b45309" />
                  <Text style={styles.ticketBadgeText}>
                    Tickets -€{ticketInfo.totalCost.toFixed(0)}
                  </Text>
                </View>
              )}

              {booking.isLastMinute && (
                <View style={styles.lastMinuteBadge}>
                  <Flame size={11} color="#e11d48" />
                  <Text style={styles.lastMinuteText}>Last Minute</Text>
                </View>
              )}
            </>
          )}

          <View
            style={[
              styles.priceBadge,
              isCancelled
                ? styles.priceBadgeCancelled
                : isReview
                ? styles.priceBadgeReview
                : styles.priceBadgeNormal,
            ]}
          >
            <Text
              style={[
                styles.priceText,
                isCancelled
                  ? styles.priceTextCancelled
                  : isReview
                  ? styles.priceTextReview
                  : styles.priceTextNormal,
              ]}
            >
              {isCancelled ? '€ 0.00 (Cancelled)' : booking.price || `€ ${priceNum.toFixed(2)}`}
            </Text>
          </View>
        </View>
      </View>

      {/* Cancelled Banner if applicable */}
      {isCancelled && (
        <View style={styles.cancelledBanner}>
          <XCircle size={13} color="#b91c1c" />
          <Text style={styles.cancelledBannerText}>
            Booking canceled by customer/GYG · Excluded from revenue & payout
          </Text>
        </View>
      )}

      {/* Tour Title */}
      <Text
        style={[styles.tourTitle, isCancelled && styles.tourTitleCancelled]}
        numberOfLines={2}
      >
        {booking.tourTitle}
      </Text>

      {booking.fareOption && (
        <Text style={styles.fareOption} numberOfLines={1}>
          {booking.fareOption}
        </Text>
      )}

      {/* Booking Details Grid */}
      <View style={styles.detailsGrid}>
        {/* Date & Time */}
        <View style={styles.detailRow}>
          <Calendar size={13} color="#64748b" />
          <Text style={styles.detailText} numberOfLines={1}>
            {booking.date}
          </Text>
        </View>

        {/* Customer & Phone */}
        <View style={styles.detailRow}>
          <User size={13} color="#64748b" />
          <Text style={styles.detailText} numberOfLines={1}>
            {booking.customerName || 'Customer'}
            {booking.participants ? ` · ${booking.participants}` : ''}
          </Text>
        </View>

        {booking.customerPhone ? (
          <TouchableOpacity
            style={styles.detailRow}
            onPress={callCustomer}
            activeOpacity={0.7}
          >
            <Phone size={13} color="#3b82f6" />
            <Text style={[styles.detailText, styles.linkText]} numberOfLines={1}>
              {booking.customerPhone} (Tap to call)
            </Text>
          </TouchableOpacity>
        ) : null}

        {/* Pickup */}
        {booking.pickup ? (
          <TouchableOpacity
            style={styles.detailRow}
            onPress={openGoogleMaps}
            activeOpacity={0.7}
          >
            <MapPin size={13} color="#3b82f6" />
            <Text style={[styles.detailText, styles.linkText]} numberOfLines={1}>
              {booking.pickup}
            </Text>
            <ExternalLink size={10} color="#3b82f6" />
          </TouchableOpacity>
        ) : null}
      </View>

      {/* Auto Ticket Cost & Net Operator Profit Breakdown */}
      {ticketInfo.hasDeduction && !isCancelled && (
        <View style={styles.ticketDeductionBox}>
          <View style={styles.ticketDeductionTop}>
            <View style={styles.ticketDeductionLeft}>
              <Ticket size={13} color="#b45309" />
              <Text style={styles.ticketDeductionTitle}>Automatic Ticket Deduction</Text>
            </View>
            <Text style={styles.ticketDeductionAmount}>-€{ticketInfo.totalCost.toFixed(2)}</Text>
          </View>

          <Text style={styles.ticketDeductionDetail}>
            {ticketInfo.breakdownText} ({ticketInfo.passengerCount} {ticketInfo.passengerCount === 1 ? 'person' : 'persons'} × €{ticketInfo.costPerPassenger.toFixed(2)})
          </Text>

          <View style={styles.ticketDivider} />

          <View style={styles.payoutSummaryRow}>
            <View style={styles.payoutCol}>
              <Text style={styles.payoutColLabel}>Gross Price</Text>
              <Text style={styles.payoutColValue}>€{priceNum.toFixed(2)}</Text>
            </View>
            <Text style={styles.payoutArrow}>→</Text>
            <View style={styles.payoutCol}>
              <Text style={styles.payoutColLabel}>GYG Payout (70%)</Text>
              <Text style={styles.payoutColValue}>€{ticketInfo.netGygPayout.toFixed(2)}</Text>
            </View>
            <Text style={styles.payoutArrow}>→</Text>
            <View style={styles.payoutColHighlight}>
              <Text style={styles.payoutColLabelHighlight}>Net Profit</Text>
              <Text style={styles.payoutColValueProfit}>€{ticketInfo.netProfitAfterTickets.toFixed(2)}</Text>
            </View>
          </View>
        </View>
      )}

      {/* Driver Assignment Section */}
      <View style={styles.driverSection}>
        <View style={styles.driverSectionLeft}>
          <UserCheck size={14} color={assignedDriver ? '#2563eb' : '#64748b'} />
          <Text style={styles.driverSectionLabel}>Driver:</Text>
          {assignedDriver ? (
            <View style={styles.driverAssignedPill}>
              <View
                style={[
                  styles.driverDot,
                  { backgroundColor: assignedDriver.color || '#3b82f6' },
                ]}
              />
              <Text style={styles.driverAssignedName}>{assignedDriver.name}</Text>
              {!isCancelled && (
                <Text style={styles.driverPayoutCut}>
                  (€{driverPayout.toFixed(2)})
                </Text>
              )}
            </View>
          ) : (
            <Text style={styles.driverUnassignedText}>Not assigned</Text>
          )}
        </View>

        <TouchableOpacity
          style={assignedDriver ? styles.changeDriverBtn : styles.assignDriverBtn}
          onPress={() => {
            Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
            setDriverModalVisible(true);
          }}
          activeOpacity={0.7}
        >
          {assignedDriver ? (
            <Text style={styles.changeDriverBtnText}>Change</Text>
          ) : (
            <>
              <Plus size={11} color="#4f46e5" />
              <Text style={styles.assignDriverBtnText}>Assign Driver</Text>
            </>
          )}
        </TouchableOpacity>
      </View>

      {/* Action Button: Generate Review & Visuals (ONLY for Review Bookings, hidden for real tours) */}
      {isReview && !isCancelled && (
        <TouchableOpacity
          style={styles.generateBtn}
          onPress={handleGenerate}
          activeOpacity={0.8}
        >
          <Sparkles size={14} color="#ffffff" />
          <Text style={styles.generateBtnText}>Generate Review & Visuals</Text>
        </TouchableOpacity>
      )}

      {/* Assign Driver Modal */}
      <Modal visible={driverModalVisible} transparent animationType="fade">
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setDriverModalVisible(false)}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Assign Driver to Tour</Text>
              <TouchableOpacity onPress={() => setDriverModalVisible(false)}>
                <X size={18} color="#64748b" />
              </TouchableOpacity>
            </View>

            <Text style={styles.modalSub}>
              Booking {booking.referenceNumber} · {booking.tourTitle}
            </Text>

            {/* Custom payout override (optional) */}
            <View style={styles.overrideSection}>
              <Text style={styles.overrideLabel}>Custom Payout Override (Optional €):</Text>
              <TextInput
                style={styles.overrideInput}
                placeholder="Leave blank to use driver rate"
                placeholderTextColor="#94a3b8"
                keyboardType="numeric"
                value={customPayoutText}
                onChangeText={setCustomPayoutText}
              />
            </View>

            <Text style={styles.selectDriverHeading}>Select Driver:</Text>

            {drivers.length === 0 ? (
              <Text style={styles.noDriversNote}>
                No drivers added yet. Please add a driver in the Drivers tab first!
              </Text>
            ) : (
              <FlatList
                data={drivers}
                keyExtractor={(item) => item.id}
                renderItem={({ item }) => {
                  const isSelected = assignedDriver?.id === item.id;
                  const estimatedCut = calculateDriverTourPayout(booking, item);
                  return (
                    <TouchableOpacity
                      style={[
                        styles.driverItem,
                        isSelected && styles.driverItemSelected,
                      ]}
                      onPress={() => handleSelectDriver(item)}
                    >
                      <View style={styles.driverItemInfo}>
                        <View
                          style={[
                            styles.driverItemAvatar,
                            { backgroundColor: item.color || '#3b82f6' },
                          ]}
                        >
                          <Text style={styles.driverItemInitial}>
                            {item.name.charAt(0)}
                          </Text>
                        </View>
                        <View>
                          <Text style={styles.driverItemName}>{item.name}</Text>
                          <Text style={styles.driverItemRate}>
                            {item.payoutType === 'percentage'
                              ? `${item.defaultPayoutRate}% Net GYG Cut`
                              : `€${item.defaultPayoutRate} Fixed per tour`}
                          </Text>
                        </View>
                      </View>

                      <View style={styles.driverItemRight}>
                        <Text style={styles.driverEstPayout}>
                          €{estimatedCut.toFixed(2)}
                        </Text>
                        {isSelected && <Check size={16} color="#4f46e5" />}
                      </View>
                    </TouchableOpacity>
                  );
                }}
              />
            )}

            {assignedDriver && (
              <TouchableOpacity
                style={styles.removeAssignmentBtn}
                onPress={handleRemoveAssignment}
                activeOpacity={0.8}
              >
                <Text style={styles.removeAssignmentBtnText}>
                  Unassign Driver from this Booking
                </Text>
              </TouchableOpacity>
            )}
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 18,
    padding: 16,
    marginHorizontal: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 6,
  },
  cardCancelled: {
    backgroundColor: '#fef2f2',
    borderColor: '#fca5a5',
    opacity: 0.9,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  refBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  refText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#334155',
    fontFamily: 'Courier',
  },
  badgesGroup: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  cancelledBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#dc2626',
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: 6,
  },
  cancelledBadgeText: {
    fontSize: 9,
    fontWeight: '900',
    color: '#ffffff',
    letterSpacing: 0.5,
  },
  cancelledBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#fee2e2',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 8,
    marginBottom: 8,
  },
  cancelledBannerText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#991b1b',
    flex: 1,
  },
  reviewBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: '#fef3c7',
    paddingHorizontal: 6,
    paddingVertical: 3,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#fde68a',
  },
  reviewBadgeText: {
    fontSize: 9,
    fontWeight: '800',
    color: '#92400e',
  },
  lastMinuteBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: '#ffe4e6',
    paddingHorizontal: 6,
    paddingVertical: 3,
    borderRadius: 6,
  },
  lastMinuteText: {
    fontSize: 9,
    fontWeight: '700',
    color: '#be123c',
  },
  priceBadge: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  priceBadgeNormal: {
    backgroundColor: '#ecfdf5',
  },
  priceBadgeReview: {
    backgroundColor: '#fef9c3',
  },
  priceBadgeCancelled: {
    backgroundColor: '#fee2e2',
  },
  priceText: {
    fontSize: 12,
    fontWeight: '800',
  },
  priceTextNormal: {
    color: '#047857',
  },
  priceTextReview: {
    color: '#854d0e',
  },
  priceTextCancelled: {
    color: '#b91c1c',
    textDecorationLine: 'line-through',
  },
  tourTitle: {
    fontSize: 15,
    fontWeight: '800',
    color: '#0f172a',
    letterSpacing: -0.3,
    marginBottom: 4,
    lineHeight: 20,
  },
  tourTitleCancelled: {
    color: '#64748b',
  },
  fareOption: {
    fontSize: 11,
    color: '#64748b',
    fontWeight: '600',
    marginBottom: 10,
  },
  detailsGrid: {
    gap: 6,
    marginBottom: 12,
    backgroundColor: '#f8fafc',
    padding: 10,
    borderRadius: 12,
  },
  detailRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  detailText: {
    fontSize: 12,
    color: '#475569',
    fontWeight: '500',
    flex: 1,
  },
  linkText: {
    color: '#2563eb',
    fontWeight: '600',
  },
  driverSection: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 10,
    marginBottom: 12,
  },
  driverSectionLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    flex: 1,
  },
  driverSectionLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#475569',
  },
  driverAssignedPill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: '#ffffff',
    paddingHorizontal: 7,
    paddingVertical: 3,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#cbd5e1',
  },
  driverDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  driverAssignedName: {
    fontSize: 11,
    fontWeight: '800',
    color: '#1e293b',
  },
  driverPayoutCut: {
    fontSize: 11,
    fontWeight: '700',
    color: '#059669',
  },
  driverUnassignedText: {
    fontSize: 11,
    color: '#94a3b8',
    fontStyle: 'italic',
  },
  assignDriverBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: '#e0e7ff',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  assignDriverBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#4338ca',
  },
  changeDriverBtn: {
    paddingHorizontal: 8,
    paddingVertical: 4,
    backgroundColor: '#e2e8f0',
    borderRadius: 6,
  },
  changeDriverBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#475569',
  },
  generateBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#4f46e5',
    paddingVertical: 10,
    borderRadius: 12,
    shadowColor: '#4f46e5',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.25,
    shadowRadius: 6,
  },
  generateBtnText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#ffffff',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 20,
  },
  modalContent: {
    width: '100%',
    maxWidth: 360,
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 18,
    maxHeight: 500,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  modalTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#0f172a',
  },
  modalSub: {
    fontSize: 11,
    color: '#64748b',
    marginBottom: 12,
  },
  overrideSection: {
    marginBottom: 14,
    backgroundColor: '#f8fafc',
    padding: 10,
    borderRadius: 10,
  },
  overrideLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: '#475569',
    marginBottom: 4,
  },
  overrideInput: {
    backgroundColor: '#ffffff',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 6,
    fontSize: 12,
    color: '#0f172a',
  },
  selectDriverHeading: {
    fontSize: 12,
    fontWeight: '800',
    color: '#334155',
    marginBottom: 8,
  },
  driverItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    paddingHorizontal: 8,
    borderRadius: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  driverItemSelected: {
    backgroundColor: '#eff6ff',
  },
  driverItemInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  driverItemAvatar: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  driverItemInitial: {
    color: '#ffffff',
    fontWeight: '800',
    fontSize: 13,
  },
  driverItemName: {
    fontSize: 13,
    fontWeight: '700',
    color: '#1e293b',
  },
  driverItemRate: {
    fontSize: 10,
    color: '#64748b',
  },
  driverItemRight: {
    alignItems: 'flex-end',
    gap: 2,
  },
  driverEstPayout: {
    fontSize: 13,
    fontWeight: '800',
    color: '#059669',
  },
  noDriversNote: {
    fontSize: 12,
    color: '#94a3b8',
    textAlign: 'center',
    marginVertical: 16,
  },
  removeAssignmentBtn: {
    marginTop: 12,
    paddingVertical: 10,
    alignItems: 'center',
    borderRadius: 10,
    backgroundColor: '#fef2f2',
  },
  removeAssignmentBtnText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#dc2626',
  },
  ticketBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#fef3c7',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#fde68a',
  },
  ticketBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#b45309',
  },
  ticketDeductionBox: {
    backgroundColor: '#fffbeb',
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#fde68a',
    padding: 12,
    marginTop: 10,
    marginBottom: 6,
  },
  ticketDeductionTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  ticketDeductionLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  ticketDeductionTitle: {
    fontSize: 12,
    fontWeight: '800',
    color: '#92400e',
    textTransform: 'uppercase',
    letterSpacing: 0.4,
  },
  ticketDeductionAmount: {
    fontSize: 13,
    fontWeight: '900',
    color: '#b45309',
  },
  ticketDeductionDetail: {
    fontSize: 11,
    color: '#78350f',
    marginBottom: 8,
  },
  ticketDivider: {
    height: 1,
    backgroundColor: '#fef3c7',
    borderBottomWidth: 1,
    borderBottomColor: '#fde68a',
    borderStyle: 'dashed',
    marginBottom: 8,
  },
  payoutSummaryRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#ffffff',
    borderRadius: 8,
    paddingVertical: 8,
    paddingHorizontal: 10,
    borderWidth: 1,
    borderColor: '#fef3c7',
  },
  payoutCol: {
    alignItems: 'center',
  },
  payoutColLabel: {
    fontSize: 9,
    color: '#64748b',
    fontWeight: '600',
    marginBottom: 2,
    textTransform: 'uppercase',
  },
  payoutColValue: {
    fontSize: 12,
    fontWeight: '700',
    color: '#1e293b',
  },
  payoutColHighlight: {
    alignItems: 'center',
    backgroundColor: '#ecfdf5',
    paddingVertical: 3,
    paddingHorizontal: 8,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#a7f3d0',
  },
  payoutColLabelHighlight: {
    fontSize: 9,
    color: '#065f46',
    fontWeight: '800',
    marginBottom: 2,
    textTransform: 'uppercase',
  },
  payoutColValueProfit: {
    fontSize: 13,
    fontWeight: '900',
    color: '#059669',
  },
  payoutArrow: {
    fontSize: 12,
    color: '#94a3b8',
    fontWeight: '600',
  },
});

import React, { useState, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  FlatList,
  Modal,
  TextInput,
  ScrollView,
  Linking,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import {
  Users,
  Plus,
  Phone,
  Calendar,
  ChevronRight,
  X,
  Wallet,
  Check,
  TrendingUp,
  Briefcase,
  Trash2,
  Edit2,
  XCircle,
  AlertTriangle,
} from 'lucide-react-native';
import { BookingItem, Driver, DriverAssignment } from '../types';
import {
  computeDriverStatistics,
  saveDriver,
  deleteDriver,
} from '../lib/driverStorage';

interface DriversScreenProps {
  bookings: BookingItem[];
  drivers: Driver[];
  assignments: Record<string, DriverAssignment>;
  onDriversUpdated: () => void | Promise<void>;
  onSelectBooking?: (booking: BookingItem) => void;
}

const COLOR_OPTIONS = [
  '#3b82f6', // Blue
  '#10b981', // Emerald
  '#8b5cf6', // Purple
  '#f59e0b', // Amber
  '#ec4899', // Pink
  '#06b6d4', // Cyan
  '#4f46e5', // Indigo
];

function formatCurrency(val: number): string {
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
  }).format(val);
}

export function DriversScreen({
  bookings,
  drivers,
  assignments,
  onDriversUpdated,
}: DriversScreenProps) {
  // Modal states
  const [addModalVisible, setAddModalVisible] = useState(false);
  const [selectedDriverDetails, setSelectedDriverDetails] = useState<Driver | null>(null);
  const [driverToDelete, setDriverToDelete] = useState<Driver | null>(null);

  // Form states for Add/Edit driver
  const [editingDriverId, setEditingDriverId] = useState<string | null>(null);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [payoutType, setPayoutType] = useState<'percentage' | 'fixed'>('percentage');
  const [rateText, setRateText] = useState('50');
  const [selectedColor, setSelectedColor] = useState(COLOR_OPTIONS[0]);
  const [notes, setNotes] = useState('');
  const [formError, setFormError] = useState<string | null>(null);

  // Compute statistics for all drivers
  const driverStatsList = useMemo(() => {
    return drivers.map((d) => computeDriverStatistics(d, bookings, assignments));
  }, [drivers, bookings, assignments]);

  // Overall totals
  const overallTotals = useMemo(() => {
    let earnings = 0;
    let totalAssignedTours = 0;
    driverStatsList.forEach((st) => {
      earnings += st.totalEarnings;
      totalAssignedTours += st.activeToursCount;
    });
    return {
      earnings,
      totalAssignedTours,
      driverCount: drivers.length,
    };
  }, [driverStatsList, drivers]);

  const openAddModal = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setEditingDriverId(null);
    setName('');
    setPhone('');
    setPayoutType('percentage');
    setRateText('50');
    setSelectedColor(COLOR_OPTIONS[Math.floor(Math.random() * COLOR_OPTIONS.length)]);
    setNotes('');
    setFormError(null);
    setAddModalVisible(true);
  };

  const openEditModal = (driver: Driver) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setEditingDriverId(driver.id);
    setName(driver.name);
    setPhone(driver.phone || '');
    setPayoutType(driver.payoutType);
    setRateText(String(driver.defaultPayoutRate));
    setSelectedColor(driver.color || COLOR_OPTIONS[0]);
    setNotes(driver.notes || '');
    setFormError(null);
    setSelectedDriverDetails(null);
    setAddModalVisible(true);
  };

  const handleSaveDriver = async () => {
    if (!name.trim()) {
      setFormError('Please enter a driver name.');
      return;
    }

    const rateNum = parseFloat(rateText.replace(',', '.'));
    if (isNaN(rateNum) || rateNum < 0) {
      setFormError('Please enter a valid payout rate or amount.');
      return;
    }

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);

    const driverToSave: Driver = {
      id: editingDriverId || `drv_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`,
      name: name.trim(),
      phone: phone.trim(),
      payoutType,
      defaultPayoutRate: rateNum,
      color: selectedColor,
      notes: notes.trim() || undefined,
      createdAt: Date.now(),
    };

    await saveDriver(driverToSave);
    setAddModalVisible(false);
    await onDriversUpdated();
  };

  const promptDeleteDriver = (driver: Driver) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setDriverToDelete(driver);
  };

  const confirmDeleteDriver = async () => {
    if (!driverToDelete) return;
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    const id = driverToDelete.id;
    setDriverToDelete(null);
    setSelectedDriverDetails(null);
    setAddModalVisible(false);
    await deleteDriver(id);
    await onDriversUpdated();
  };

  // Selected driver's detailed statistics
  const activeDetailStats = useMemo(() => {
    if (!selectedDriverDetails) return null;
    return computeDriverStatistics(selectedDriverDetails, bookings, assignments);
  }, [selectedDriverDetails, bookings, assignments]);

  return (
    <View style={styles.container}>
      {/* Top Header */}
      <View style={styles.header}>
        <View>
          <Text style={styles.headerTitle}>Drivers & Earnings</Text>
          <Text style={styles.headerSub}>Manage fleet and tour payouts</Text>
        </View>

        <TouchableOpacity
          style={styles.addDriverBtn}
          onPress={openAddModal}
          activeOpacity={0.8}
        >
          <Plus size={16} color="#ffffff" />
          <Text style={styles.addDriverBtnText}>Add Driver</Text>
        </TouchableOpacity>
      </View>

      {/* Aggregate Overview Cards */}
      <View style={styles.overviewCardsRow}>
        {/* Total Driver Payouts */}
        <View style={[styles.overviewCard, styles.overviewCardHighlight]}>
          <View style={styles.cardIconBox}>
            <Wallet size={16} color="#059669" />
          </View>
          <Text style={styles.cardValHighlight}>
            {formatCurrency(overallTotals.earnings)}
          </Text>
          <Text style={styles.cardLabel}>Total Driver Earnings</Text>
        </View>

        {/* Assigned Tours */}
        <View style={styles.overviewCard}>
          <View style={[styles.cardIconBox, styles.iconBoxBlue]}>
            <Briefcase size={16} color="#2563eb" />
          </View>
          <Text style={styles.cardVal}>{overallTotals.totalAssignedTours}</Text>
          <Text style={styles.cardLabel}>Assigned Tours</Text>
        </View>

        {/* Fleet Count */}
        <View style={styles.overviewCard}>
          <View style={[styles.cardIconBox, styles.iconBoxPurple]}>
            <Users size={16} color="#7c3aed" />
          </View>
          <Text style={styles.cardVal}>{overallTotals.driverCount}</Text>
          <Text style={styles.cardLabel}>Active Drivers</Text>
        </View>
      </View>

      {/* Driver List */}
      <FlatList
        data={driverStatsList}
        keyExtractor={(item) => item.driver.id}
        showsVerticalScrollIndicator={false}
        contentContainerStyle={styles.listContent}
        renderItem={({ item }) => {
          const { driver, totalEarnings, activeToursCount, upcomingCount } = item;

          return (
            <TouchableOpacity
              style={styles.driverCard}
              onPress={() => {
                Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
                setSelectedDriverDetails(driver);
              }}
              activeOpacity={0.7}
            >
              {/* Top Row: Avatar + Name + Earnings + Delete Trash Button */}
              <View style={styles.driverCardTop}>
                <View style={styles.driverInfoLeft}>
                  <View
                    style={[
                      styles.avatar,
                      { backgroundColor: driver.color || '#3b82f6' },
                    ]}
                  >
                    <Text style={styles.avatarText}>
                      {driver.name.charAt(0).toUpperCase()}
                    </Text>
                  </View>

                  <View style={{ flex: 1 }}>
                    <Text style={styles.driverName} numberOfLines={1}>
                      {driver.name}
                    </Text>
                    <Text style={styles.driverRateLabel}>
                      {driver.payoutType === 'percentage'
                        ? `${driver.defaultPayoutRate}% Net GYG Cut`
                        : `€${driver.defaultPayoutRate.toFixed(2)} Fixed / Tour`}
                    </Text>
                  </View>
                </View>

                {/* Right Actions: Earnings Pill + Delete Button */}
                <View style={styles.topRightActions}>
                  <View style={styles.earningsPill}>
                    <Text style={styles.earningsPillLabel}>EARNINGS</Text>
                    <Text style={styles.earningsPillAmount}>
                      {formatCurrency(totalEarnings)}
                    </Text>
                  </View>

                  <TouchableOpacity
                    style={styles.cardTrashBtn}
                    onPress={(e) => {
                      e.stopPropagation();
                      promptDeleteDriver(driver);
                    }}
                    hitSlop={{ top: 8, bottom: 8, left: 8, right: 8 }}
                  >
                    <Trash2 size={16} color="#ef4444" />
                  </TouchableOpacity>
                </View>
              </View>

              {/* Middle Row: Phone & Stats */}
              <View style={styles.driverStatsRow}>
                {driver.phone ? (
                  <TouchableOpacity
                    style={styles.phonePill}
                    onPress={() =>
                      Linking.openURL(`tel:${driver.phone.replace(/\s+/g, '')}`)
                    }
                    activeOpacity={0.7}
                  >
                    <Phone size={12} color="#2563eb" />
                    <Text style={styles.phonePillText}>{driver.phone}</Text>
                  </TouchableOpacity>
                ) : (
                  <View />
                )}

                <View style={styles.tourCountBadges}>
                  <View style={styles.toursBadge}>
                    <Text style={styles.toursBadgeText}>
                      {activeToursCount} tours
                    </Text>
                  </View>
                  <View style={styles.upcomingBadge}>
                    <Text style={styles.upcomingBadgeText}>
                      {upcomingCount} upcoming
                    </Text>
                  </View>
                </View>
              </View>

              {/* Bottom: Tap to view tours */}
              <View style={styles.driverCardFooter}>
                <Text style={styles.viewToursText}>
                  View assigned bookings & payout details
                </Text>
                <ChevronRight size={14} color="#94a3b8" />
              </View>
            </TouchableOpacity>
          );
        }}
        ListEmptyComponent={
          <View style={styles.emptyState}>
            <Users size={48} color="#cbd5e1" />
            <Text style={styles.emptyStateTitle}>No drivers added yet</Text>
            <Text style={styles.emptyStateSub}>
              Tap the "+ Add Driver" button above to add your first driver, set their payout rate, and assign them to bookings.
            </Text>
          </View>
        }
      />

      {/* Add / Edit Driver Modal */}
      <Modal visible={addModalVisible} transparent animationType="slide">
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setAddModalVisible(false)}
        >
          <View
            style={styles.modalContent}
            onStartShouldSetResponder={() => true}
          >
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>
                {editingDriverId ? 'Edit Driver' : 'Add New Driver'}
              </Text>
              <TouchableOpacity onPress={() => setAddModalVisible(false)}>
                <X size={20} color="#64748b" />
              </TouchableOpacity>
            </View>

            {formError ? (
              <View style={styles.formErrorBox}>
                <AlertTriangle size={14} color="#dc2626" />
                <Text style={styles.formErrorText}>{formError}</Text>
              </View>
            ) : null}

            <ScrollView showsVerticalScrollIndicator={false}>
              {/* Name */}
              <Text style={styles.inputLabel}>Driver Full Name *</Text>
              <TextInput
                style={styles.input}
                placeholder="e.g. Marco Rossi"
                placeholderTextColor="#94a3b8"
                value={name}
                onChangeText={(t) => {
                  setName(t);
                  setFormError(null);
                }}
              />

              {/* Phone */}
              <Text style={styles.inputLabel}>Phone Number (for direct calling)</Text>
              <TextInput
                style={styles.input}
                placeholder="e.g. +43 664 1234567"
                placeholderTextColor="#94a3b8"
                keyboardType="phone-pad"
                value={phone}
                onChangeText={setPhone}
              />

              {/* Payout Type Selector */}
              <Text style={styles.inputLabel}>Payout Calculation Type *</Text>
              <View style={styles.typeSelectorRow}>
                <TouchableOpacity
                  style={[
                    styles.typeBtn,
                    payoutType === 'percentage' && styles.typeBtnActive,
                  ]}
                  onPress={() => {
                    Haptics.selectionAsync();
                    setPayoutType('percentage');
                    if (rateText === '120' || rateText === '150') setRateText('50');
                  }}
                >
                  <Text
                    style={[
                      styles.typeBtnText,
                      payoutType === 'percentage' && styles.typeBtnTextActive,
                    ]}
                  >
                    % of Net GYG Cut
                  </Text>
                </TouchableOpacity>

                <TouchableOpacity
                  style={[
                    styles.typeBtn,
                    payoutType === 'fixed' && styles.typeBtnActive,
                  ]}
                  onPress={() => {
                    Haptics.selectionAsync();
                    setPayoutType('fixed');
                    if (rateText === '50') setRateText('150');
                  }}
                >
                  <Text
                    style={[
                      styles.typeBtnText,
                      payoutType === 'fixed' && styles.typeBtnTextActive,
                    ]}
                  >
                    Fixed EUR per Tour
                  </Text>
                </TouchableOpacity>
              </View>

              {/* Rate Input */}
              <Text style={styles.inputLabel}>
                {payoutType === 'percentage'
                  ? 'Default Cut Percentage (% of 70% Net Payout)'
                  : 'Default Fixed Payout Amount (€)'}
              </Text>
              <TextInput
                style={styles.input}
                placeholder={payoutType === 'percentage' ? 'e.g. 50' : 'e.g. 150'}
                placeholderTextColor="#94a3b8"
                keyboardType="numeric"
                value={rateText}
                onChangeText={(t) => {
                  setRateText(t);
                  setFormError(null);
                }}
              />

              {/* Color Tag */}
              <Text style={styles.inputLabel}>Avatar Badge Color</Text>
              <View style={styles.colorRow}>
                {COLOR_OPTIONS.map((c) => {
                  const isSel = selectedColor === c;
                  return (
                    <TouchableOpacity
                      key={c}
                      style={[
                        styles.colorCircle,
                        { backgroundColor: c },
                        isSel && styles.colorCircleSelected,
                      ]}
                      onPress={() => setSelectedColor(c)}
                    >
                      {isSel && <Check size={14} color="#ffffff" />}
                    </TouchableOpacity>
                  );
                })}
              </View>

              {/* Notes */}
              <Text style={styles.inputLabel}>Notes / Vehicle / Language (Optional)</Text>
              <TextInput
                style={[styles.input, styles.notesInput]}
                placeholder="e.g. Mercedes V-Class, English & German"
                placeholderTextColor="#94a3b8"
                multiline
                value={notes}
                onChangeText={setNotes}
              />

              {/* Save Button */}
              <TouchableOpacity
                style={styles.saveBtn}
                onPress={handleSaveDriver}
                activeOpacity={0.8}
              >
                <Text style={styles.saveBtnText}>
                  {editingDriverId ? 'Update Driver' : 'Save Driver'}
                </Text>
              </TouchableOpacity>

              {/* Delete Driver Button in Edit Mode */}
              {editingDriverId && (
                <TouchableOpacity
                  style={styles.deleteInModalBtn}
                  onPress={() => {
                    const d = drivers.find((x) => x.id === editingDriverId);
                    if (d) promptDeleteDriver(d);
                  }}
                  activeOpacity={0.8}
                >
                  <Trash2 size={15} color="#dc2626" />
                  <Text style={styles.deleteInModalBtnText}>Delete This Driver</Text>
                </TouchableOpacity>
              )}
            </ScrollView>
          </View>
        </TouchableOpacity>
      </Modal>

      {/* Driver Details & Assigned Tours Breakdown Modal */}
      <Modal
        visible={!!selectedDriverDetails}
        transparent
        animationType="slide"
      >
        <View style={styles.detailModalOverlay}>
          <View style={styles.detailModalContent}>
            {/* Modal Top Header */}
            <View style={styles.detailHeader}>
              <View style={styles.detailHeaderLeft}>
                <View
                  style={[
                    styles.avatarLarge,
                    {
                      backgroundColor:
                        selectedDriverDetails?.color || '#3b82f6',
                    },
                  ]}
                >
                  <Text style={styles.avatarLargeText}>
                    {selectedDriverDetails?.name.charAt(0).toUpperCase()}
                  </Text>
                </View>
                <View style={{ flex: 1 }}>
                  <Text style={styles.detailDriverName} numberOfLines={1}>
                    {selectedDriverDetails?.name}
                  </Text>
                  <Text style={styles.detailDriverRate}>
                    {selectedDriverDetails?.payoutType === 'percentage'
                      ? `${selectedDriverDetails.defaultPayoutRate}% Net GYG Cut`
                      : `€${selectedDriverDetails?.defaultPayoutRate} Fixed per tour`}
                  </Text>
                </View>
              </View>

              <TouchableOpacity
                onPress={() => setSelectedDriverDetails(null)}
                style={styles.closeBtn}
              >
                <X size={20} color="#64748b" />
              </TouchableOpacity>
            </View>

            {/* Total Earnings Highlight Banner */}
            <View style={styles.detailEarningsBanner}>
              <View>
                <Text style={styles.detailEarningsLabel}>
                  TOTAL ACCUMULATED EARNINGS
                </Text>
                <Text style={styles.detailEarningsValue}>
                  {formatCurrency(activeDetailStats?.totalEarnings || 0)}
                </Text>
              </View>
              <View style={styles.detailToursCount}>
                <TrendingUp size={16} color="#059669" />
                <Text style={styles.detailToursCountText}>
                  {activeDetailStats?.activeToursCount || 0} active tours
                </Text>
              </View>
            </View>

            {/* Quick Actions (Call, Edit, Delete) */}
            <View style={styles.detailActionButtons}>
              {selectedDriverDetails?.phone ? (
                <TouchableOpacity
                  style={styles.detailActionCall}
                  onPress={() =>
                    Linking.openURL(
                      `tel:${selectedDriverDetails.phone.replace(/\s+/g, '')}`
                    )
                  }
                >
                  <Phone size={14} color="#ffffff" />
                  <Text style={styles.detailActionCallText}>Call</Text>
                </TouchableOpacity>
              ) : null}

              <TouchableOpacity
                style={styles.detailActionEdit}
                onPress={() =>
                  selectedDriverDetails && openEditModal(selectedDriverDetails)
                }
              >
                <Edit2 size={14} color="#475569" />
                <Text style={styles.detailActionEditText}>Edit</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.detailActionDelete}
                onPress={() =>
                  selectedDriverDetails &&
                  promptDeleteDriver(selectedDriverDetails)
                }
              >
                <Trash2 size={14} color="#dc2626" />
                <Text style={styles.detailActionDeleteText}>Delete</Text>
              </TouchableOpacity>
            </View>

            {/* Assigned Bookings List */}
            <Text style={styles.assignedToursHeading}>
              Assigned Tours Breakdown ({activeDetailStats?.tours.length || 0})
            </Text>

            <FlatList
              data={activeDetailStats?.tours || []}
              keyExtractor={(item) =>
                item.booking.referenceNumber || item.booking.id
              }
              showsVerticalScrollIndicator={false}
              renderItem={({ item }) => {
                const { booking, payout, isCancelled } = item;

                return (
                  <View
                    style={[
                      styles.tourBreakdownItem,
                      isCancelled && styles.tourBreakdownItemCancelled,
                    ]}
                  >
                    <View style={styles.tourBreakdownTop}>
                      <View style={styles.tourRefPill}>
                        <Text style={styles.tourRefText}>
                          {booking.referenceNumber}
                        </Text>
                      </View>

                      {isCancelled ? (
                        <View style={styles.breakdownCancelledBadge}>
                          <XCircle size={10} color="#ffffff" />
                          <Text style={styles.breakdownCancelledText}>
                            CANCELLED (€0.00)
                          </Text>
                        </View>
                      ) : (
                        <View style={styles.breakdownPayoutBadge}>
                          <Text style={styles.breakdownPayoutText}>
                            Driver Cut: {formatCurrency(payout)}
                          </Text>
                        </View>
                      )}
                    </View>

                    <Text style={styles.breakdownTourTitle} numberOfLines={2}>
                      {booking.tourTitle}
                    </Text>

                    <View style={styles.breakdownMetaRow}>
                      <View style={styles.breakdownMetaItem}>
                        <Calendar size={11} color="#64748b" />
                        <Text style={styles.breakdownMetaText}>
                          {booking.date}
                        </Text>
                      </View>

                      <Text style={styles.breakdownGrossPrice}>
                        GYG Price: {booking.price}
                      </Text>
                    </View>

                    {booking.customerName ? (
                      <Text style={styles.breakdownCustomer}>
                        Customer: {booking.customerName}
                        {booking.pickup ? ` · ${booking.pickup}` : ''}
                      </Text>
                    ) : null}
                  </View>
                );
              }}
              ListEmptyComponent={
                <View style={styles.noAssignedToursState}>
                  <Text style={styles.noAssignedToursText}>
                    No tours assigned to this driver yet.
                  </Text>
                  <Text style={styles.noAssignedToursSub}>
                    Open the Bookings or Calendar tab and tap "+ Assign Driver" on any booking to assign it to {selectedDriverDetails?.name}.
                  </Text>
                </View>
              }
            />
          </View>
        </View>
      </Modal>

      {/* Delete Driver Confirmation Modal */}
      <Modal visible={!!driverToDelete} transparent animationType="fade">
        <TouchableOpacity
          style={styles.confirmModalOverlay}
          activeOpacity={1}
          onPress={() => setDriverToDelete(null)}
        >
          <View style={styles.confirmModalContent}>
            <View style={styles.trashCircle}>
              <Trash2 size={24} color="#dc2626" />
            </View>
            <Text style={styles.confirmTitle}>Delete Driver?</Text>
            <Text style={styles.confirmMessage}>
              Are you sure you want to remove{' '}
              <Text style={{ fontWeight: '800', color: '#0f172a' }}>
                {driverToDelete?.name}
              </Text>
              ? Any tours assigned to this driver will be unassigned and driver earnings will be removed.
            </Text>

            <View style={styles.confirmBtnRow}>
              <TouchableOpacity
                style={styles.cancelBtn}
                onPress={() => setDriverToDelete(null)}
                activeOpacity={0.8}
              >
                <Text style={styles.cancelBtnText}>Cancel</Text>
              </TouchableOpacity>
              <TouchableOpacity
                style={styles.deleteConfirmBtn}
                onPress={confirmDeleteDriver}
                activeOpacity={0.8}
              >
                <Text style={styles.deleteConfirmBtnText}>Delete Driver</Text>
              </TouchableOpacity>
            </View>
          </View>
        </TouchableOpacity>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingTop: 12,
    paddingBottom: 8,
    backgroundColor: '#ffffff',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '900',
    color: '#0f172a',
    letterSpacing: -0.4,
  },
  headerSub: {
    fontSize: 11,
    color: '#64748b',
    marginTop: 2,
  },
  addDriverBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#4f46e5',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 12,
    shadowColor: '#4f46e5',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  addDriverBtnText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: '800',
  },
  overviewCardsRow: {
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 16,
    marginVertical: 12,
  },
  overviewCard: {
    flex: 1,
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 12,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  overviewCardHighlight: {
    backgroundColor: '#ecfdf5',
    borderColor: '#a7f3d0',
  },
  cardIconBox: {
    width: 26,
    height: 26,
    borderRadius: 8,
    backgroundColor: '#d1fae5',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 6,
  },
  iconBoxBlue: {
    backgroundColor: '#dbeafe',
  },
  iconBoxPurple: {
    backgroundColor: '#ede9fe',
  },
  cardVal: {
    fontSize: 16,
    fontWeight: '900',
    color: '#0f172a',
  },
  cardValHighlight: {
    fontSize: 16,
    fontWeight: '900',
    color: '#065f46',
  },
  cardLabel: {
    fontSize: 10,
    fontWeight: '600',
    color: '#64748b',
    marginTop: 2,
  },
  listContent: {
    paddingHorizontal: 16,
    paddingBottom: 24,
  },
  driverCard: {
    backgroundColor: '#ffffff',
    borderRadius: 18,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 6,
  },
  driverCardTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  driverInfoLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
  },
  avatar: {
    width: 42,
    height: 42,
    borderRadius: 21,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    color: '#ffffff',
    fontSize: 18,
    fontWeight: '900',
  },
  driverName: {
    fontSize: 15,
    fontWeight: '800',
    color: '#0f172a',
  },
  driverRateLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: '#64748b',
    marginTop: 2,
  },
  topRightActions: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  cardTrashBtn: {
    width: 32,
    height: 32,
    borderRadius: 8,
    backgroundColor: '#fef2f2',
    alignItems: 'center',
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#fee2e2',
  },
  earningsPill: {
    alignItems: 'flex-end',
    backgroundColor: '#ecfdf5',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#a7f3d0',
  },
  earningsPillLabel: {
    fontSize: 8,
    fontWeight: '800',
    color: '#065f46',
    letterSpacing: 0.5,
  },
  earningsPillAmount: {
    fontSize: 14,
    fontWeight: '900',
    color: '#047857',
  },
  driverStatsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
    paddingBottom: 10,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  phonePill: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: '#eff6ff',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  phonePillText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#2563eb',
  },
  tourCountBadges: {
    flexDirection: 'row',
    gap: 6,
  },
  toursBadge: {
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
  },
  toursBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#475569',
  },
  upcomingBadge: {
    backgroundColor: '#eef2ff',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
  },
  upcomingBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#4f46e5',
  },
  driverCardFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  viewToursText: {
    fontSize: 11,
    fontWeight: '600',
    color: '#64748b',
  },
  emptyState: {
    paddingVertical: 60,
    alignItems: 'center',
    justifyContent: 'center',
  },
  emptyStateTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#334155',
    marginTop: 12,
  },
  emptyStateSub: {
    fontSize: 12,
    color: '#94a3b8',
    textAlign: 'center',
    maxWidth: 280,
    marginTop: 6,
    lineHeight: 18,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    justifyContent: 'flex-end',
  },
  modalContent: {
    backgroundColor: '#ffffff',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 20,
    maxHeight: '90%',
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0f172a',
  },
  formErrorBox: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#fef2f2',
    padding: 10,
    borderRadius: 10,
    marginBottom: 10,
  },
  formErrorText: {
    color: '#dc2626',
    fontSize: 12,
    fontWeight: '600',
  },
  inputLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#334155',
    marginBottom: 6,
    marginTop: 10,
  },
  input: {
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#e2e8f0',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 13,
    color: '#0f172a',
  },
  notesInput: {
    height: 60,
    textAlignVertical: 'top',
  },
  typeSelectorRow: {
    flexDirection: 'row',
    gap: 8,
  },
  typeBtn: {
    flex: 1,
    backgroundColor: '#f1f5f9',
    paddingVertical: 10,
    alignItems: 'center',
    borderRadius: 10,
  },
  typeBtnActive: {
    backgroundColor: '#4f46e5',
  },
  typeBtnText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#475569',
  },
  typeBtnTextActive: {
    color: '#ffffff',
  },
  colorRow: {
    flexDirection: 'row',
    gap: 10,
    marginVertical: 4,
  },
  colorCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  colorCircleSelected: {
    borderWidth: 3,
    borderColor: '#0f172a',
  },
  saveBtn: {
    backgroundColor: '#4f46e5',
    borderRadius: 14,
    paddingVertical: 12,
    alignItems: 'center',
    marginTop: 16,
  },
  saveBtnText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '800',
  },
  deleteInModalBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#fef2f2',
    borderWidth: 1,
    borderColor: '#fee2e2',
    borderRadius: 14,
    paddingVertical: 12,
    marginTop: 10,
    marginBottom: 20,
  },
  deleteInModalBtnText: {
    color: '#dc2626',
    fontSize: 13,
    fontWeight: '700',
  },
  detailModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    justifyContent: 'flex-end',
  },
  detailModalContent: {
    backgroundColor: '#ffffff',
    borderTopLeftRadius: 24,
    borderTopRightRadius: 24,
    padding: 20,
    maxHeight: '90%',
    flex: 1,
  },
  detailHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 14,
  },
  detailHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    flex: 1,
  },
  avatarLarge: {
    width: 48,
    height: 48,
    borderRadius: 24,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarLargeText: {
    color: '#ffffff',
    fontSize: 20,
    fontWeight: '900',
  },
  detailDriverName: {
    fontSize: 17,
    fontWeight: '900',
    color: '#0f172a',
  },
  detailDriverRate: {
    fontSize: 11,
    color: '#64748b',
    marginTop: 2,
  },
  closeBtn: {
    width: 32,
    height: 32,
    borderRadius: 16,
    backgroundColor: '#f1f5f9',
    alignItems: 'center',
    justifyContent: 'center',
  },
  detailEarningsBanner: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#ecfdf5',
    borderRadius: 16,
    padding: 14,
    borderWidth: 1,
    borderColor: '#a7f3d0',
    marginBottom: 14,
  },
  detailEarningsLabel: {
    fontSize: 10,
    fontWeight: '800',
    color: '#065f46',
    letterSpacing: 0.5,
  },
  detailEarningsValue: {
    fontSize: 24,
    fontWeight: '900',
    color: '#047857',
    marginTop: 2,
  },
  detailToursCount: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: 'rgba(16, 185, 129, 0.15)',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 10,
  },
  detailToursCountText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#065f46',
  },
  detailActionButtons: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 16,
  },
  detailActionCall: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#2563eb',
    paddingVertical: 10,
    borderRadius: 12,
  },
  detailActionCallText: {
    color: '#ffffff',
    fontSize: 12,
    fontWeight: '800',
  },
  detailActionEdit: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
  },
  detailActionEditText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#334155',
  },
  detailActionDelete: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#fef2f2',
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
  },
  detailActionDeleteText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#dc2626',
  },
  assignedToursHeading: {
    fontSize: 13,
    fontWeight: '800',
    color: '#0f172a',
    marginBottom: 10,
  },
  tourBreakdownItem: {
    backgroundColor: '#f8fafc',
    borderRadius: 14,
    padding: 12,
    marginBottom: 8,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  tourBreakdownItemCancelled: {
    backgroundColor: '#fef2f2',
    borderColor: '#fca5a5',
  },
  tourBreakdownTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 6,
  },
  tourRefPill: {
    backgroundColor: '#ffffff',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  tourRefText: {
    fontSize: 10,
    fontWeight: '800',
    color: '#475569',
    fontFamily: 'Courier',
  },
  breakdownCancelledBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
    backgroundColor: '#dc2626',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  breakdownCancelledText: {
    fontSize: 9,
    fontWeight: '900',
    color: '#ffffff',
  },
  breakdownPayoutBadge: {
    backgroundColor: '#ecfdf5',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 6,
  },
  breakdownPayoutText: {
    fontSize: 11,
    fontWeight: '800',
    color: '#047857',
  },
  breakdownTourTitle: {
    fontSize: 13,
    fontWeight: '800',
    color: '#0f172a',
    marginBottom: 4,
  },
  breakdownMetaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 4,
  },
  breakdownMetaItem: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
  },
  breakdownMetaText: {
    fontSize: 11,
    color: '#64748b',
    fontWeight: '500',
  },
  breakdownGrossPrice: {
    fontSize: 11,
    color: '#64748b',
    fontWeight: '600',
  },
  breakdownCustomer: {
    fontSize: 11,
    color: '#475569',
  },
  noAssignedToursState: {
    paddingVertical: 30,
    alignItems: 'center',
  },
  noAssignedToursText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#64748b',
  },
  noAssignedToursSub: {
    fontSize: 11,
    color: '#94a3b8',
    textAlign: 'center',
    marginTop: 4,
    maxWidth: 260,
  },
  confirmModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.65)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
  confirmModalContent: {
    width: '100%',
    maxWidth: 320,
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 20,
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.15,
    shadowRadius: 12,
  },
  trashCircle: {
    width: 52,
    height: 52,
    borderRadius: 26,
    backgroundColor: '#fee2e2',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 12,
  },
  confirmTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: '#0f172a',
    marginBottom: 8,
  },
  confirmMessage: {
    fontSize: 13,
    color: '#64748b',
    textAlign: 'center',
    lineHeight: 18,
    marginBottom: 20,
  },
  confirmBtnRow: {
    flexDirection: 'row',
    gap: 10,
    width: '100%',
  },
  cancelBtn: {
    flex: 1,
    backgroundColor: '#f1f5f9',
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
  },
  cancelBtnText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#475569',
  },
  deleteConfirmBtn: {
    flex: 1,
    backgroundColor: '#dc2626',
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
  },
  deleteConfirmBtnText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#ffffff',
  },
});

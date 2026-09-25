import React, { useState, useEffect, useMemo } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Alert,
  ActivityIndicator,
  Switch,
  Modal,
} from 'react-native';
import * as Haptics from 'expo-haptics';
import {
  Settings2,
  Globe,
  Mail,
  Key,
  Check,
  RefreshCw,
  Ticket,
  Plus,
  Trash2,
  X,
  Info,
  Sparkles,
  Search,
} from 'lucide-react-native';
import {
  getApiBaseUrl,
  setApiBaseUrl,
  getZohoConfig,
  saveZohoConfig,
  getGeminiKey,
  saveGeminiKey,
  DEFAULT_API_URL,
  fetchLiveBookings,
} from '../api/client';
import { BookingItem, TourTicketRule } from '../types';
import {
  getStoredTicketRules,
  saveTicketRule,
  deleteTicketRule,
  toggleTicketRule,
} from '../lib/ticketRulesStorage';

interface SettingsScreenProps {
  onSettingsSaved: () => void;
  bookings?: BookingItem[];
  ticketRules?: TourTicketRule[];
  onTicketRulesUpdated?: () => void | Promise<void>;
}

export function SettingsScreen({
  onSettingsSaved,
  bookings = [],
  ticketRules: propTicketRules,
  onTicketRulesUpdated,
}: SettingsScreenProps) {
  const [activeTab, setActiveTab] = useState<'tickets' | 'credentials'>('tickets');

  // Ticket Rules state
  const [rules, setRules] = useState<TourTicketRule[]>(propTicketRules || []);
  const [modalVisible, setModalVisible] = useState(false);
  const [tourKeyword, setTourKeyword] = useState('');
  const [ticketCostText, setTicketCostText] = useState('49');
  const [fixedCostText, setFixedCostText] = useState('');
  const [descriptionText, setDescriptionText] = useState('');

  // Credentials & Sync state
  const [apiUrl, setApiUrl] = useState(DEFAULT_API_URL);
  const [zohoEmail, setZohoEmail] = useState('');
  const [zohoPassword, setZohoPassword] = useState('');
  const [zohoHost, setZohoHost] = useState('imappro.zoho.eu');
  const [geminiKey, setGeminiKey] = useState('');
  const [isTesting, setIsTesting] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState(false);

  // Load stored ticket rules and settings on mount
  useEffect(() => {
    (async () => {
      const storedRules = await getStoredTicketRules();
      setRules(storedRules);

      const savedUrl = await getApiBaseUrl();
      setApiUrl(savedUrl);

      const savedZoho = await getZohoConfig();
      if (savedZoho) {
        if (savedZoho.email) setZohoEmail(savedZoho.email);
        if (savedZoho.password) setZohoPassword(savedZoho.password);
        if (savedZoho.host) setZohoHost(savedZoho.host);
      }

      const savedKey = await getGeminiKey();
      if (savedKey) setGeminiKey(savedKey);
    })();
  }, []);

  // Sync prop ticket rules if updated from parent
  useEffect(() => {
    if (propTicketRules && propTicketRules.length > 0) {
      setRules(propTicketRules);
    }
  }, [propTicketRules]);

  // Unique tour titles from current bookings to suggest
  const existingTourTitles = useMemo(() => {
    const set = new Set<string>();
    bookings.forEach((b) => {
      if (b.tourTitle && b.tourTitle.trim().length > 3) {
        set.add(b.tourTitle.trim());
      }
    });
    return Array.from(set);
  }, [bookings]);

  // Refresh ticket rules helper
  const reloadRules = async () => {
    const updated = await getStoredTicketRules();
    setRules(updated);
    if (onTicketRulesUpdated) {
      await onTicketRulesUpdated();
    }
  };

  const handleToggleRule = async (ruleId: string) => {
    Haptics.selectionAsync();
    await toggleTicketRule(ruleId);
    await reloadRules();
  };

  const handleDeleteRule = (rule: TourTicketRule) => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
    Alert.alert(
      'Delete Ticket Rule',
      `Are you sure you want to remove the ticket deduction for "${rule.tourKeyword}"?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await deleteTicketRule(rule.id);
            await reloadRules();
          },
        },
      ]
    );
  };

  const handleOpenAddModal = (initialTour?: string) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    if (initialTour) {
      setTourKeyword(initialTour);
      setDescriptionText(`Admission tickets for ${initialTour}`);
    } else {
      setTourKeyword('');
      setDescriptionText('');
    }
    setTicketCostText('49');
    setFixedCostText('');
    setModalVisible(true);
  };

  const handleSaveRule = async () => {
    const kw = tourKeyword.trim();
    if (!kw) {
      Alert.alert('Required', 'Please enter a tour title keyword (e.g. Hallstatt Salt Mine).');
      return;
    }

    const costNum = parseFloat(ticketCostText.replace(',', '.'));
    if (isNaN(costNum) || costNum < 0) {
      Alert.alert('Invalid Cost', 'Please enter a valid ticket cost per passenger (e.g. 49).');
      return;
    }

    const fixedNum = parseFloat(fixedCostText.replace(',', '.'));
    const fixedCost = !isNaN(fixedNum) && fixedNum > 0 ? fixedNum : undefined;

    const newRule: TourTicketRule = {
      id: `rule_${Date.now()}`,
      tourKeyword: kw,
      tourNamePattern: kw,
      ticketCostPerPassenger: costNum,
      fixedBookingCost: fixedCost,
      description: descriptionText.trim() || `€${costNum.toFixed(2)} ticket per passenger`,
      isEnabled: true,
      createdAt: Date.now(),
    };

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await saveTicketRule(newRule);
    await reloadRules();
    setModalVisible(false);
  };

  // Save Settings Handlers
  const handleSave = async () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await setApiBaseUrl(apiUrl.trim() || DEFAULT_API_URL);

    if (zohoEmail.trim()) {
      await saveZohoConfig({
        email: zohoEmail.trim(),
        password: zohoPassword.trim() || undefined,
        host: zohoHost.trim() || 'imappro.zoho.eu',
      });
    }

    if (geminiKey.trim()) {
      await saveGeminiKey(geminiKey.trim());
    }

    setSaveSuccess(true);
    setTimeout(() => setSaveSuccess(false), 2000);
    onSettingsSaved();
  };

  const handleTestConnection = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setIsTesting(true);

    try {
      await handleSave();
      const res = await fetchLiveBookings(true);

      if (res.success) {
        Alert.alert(
          'Connection Successful! 🎉',
          `Connected to ${res.source === 'zoho' ? 'Zoho Mail IMAP' : 'Backend API'}.\nTotal bookings fetched: ${res.total}`
        );
      } else {
        Alert.alert('Notice', res.error || 'Server did not return bookings.');
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Connection failed';
      Alert.alert('Connection Failed', msg);
    } finally {
      setIsTesting(false);
    }
  };

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
      {/* Top Header */}
      <View style={styles.header}>
        <View style={styles.headerIcon}>
          <Settings2 size={20} color="#ffffff" />
        </View>
        <View>
          <Text style={styles.title}>App Configuration</Text>
          <Text style={styles.subtitle}>Ticket deductions, sync & credentials</Text>
        </View>
      </View>

      {/* Tabs */}
      <View style={styles.tabContainer}>
        <TouchableOpacity
          style={[styles.tabBtn, activeTab === 'tickets' && styles.tabBtnActive]}
          onPress={() => {
            Haptics.selectionAsync();
            setActiveTab('tickets');
          }}
          activeOpacity={0.8}
        >
          <Ticket size={16} color={activeTab === 'tickets' ? '#ffffff' : '#64748b'} />
          <Text style={[styles.tabBtnText, activeTab === 'tickets' && styles.tabBtnTextActive]}>
            Ticket Deductions ({rules.filter((r) => r.isEnabled).length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.tabBtn, activeTab === 'credentials' && styles.tabBtnActive]}
          onPress={() => {
            Haptics.selectionAsync();
            setActiveTab('credentials');
          }}
          activeOpacity={0.8}
        >
          <Globe size={16} color={activeTab === 'credentials' ? '#ffffff' : '#64748b'} />
          <Text
            style={[styles.tabBtnText, activeTab === 'credentials' && styles.tabBtnTextActive]}
          >
            Sync & API
          </Text>
        </TouchableOpacity>
      </View>

      {/* TAB 1: TICKET DEDUCTIONS */}
      {activeTab === 'tickets' && (
        <View style={styles.tabContent}>
          {/* Explanation Info Box */}
          <View style={styles.infoBanner}>
            <Info size={16} color="#0284c7" />
            <Text style={styles.infoBannerText}>
              Configured tours will <Text style={styles.boldText}>automatically deduct</Text> ticket
              costs per passenger from your Net GYG Payout across all screens.
            </Text>
          </View>

          {/* Action Row: Add Rule */}
          <View style={styles.sectionHeaderRow}>
            <Text style={styles.sectionTitle}>Active Tour Rules</Text>
            <TouchableOpacity
              style={styles.addRuleBtn}
              onPress={() => handleOpenAddModal()}
              activeOpacity={0.8}
            >
              <Plus size={14} color="#ffffff" />
              <Text style={styles.addRuleBtnText}>Add Tour Rule</Text>
            </TouchableOpacity>
          </View>

          {/* Rules List */}
          {rules.length === 0 ? (
            <View style={styles.emptyCard}>
              <Ticket size={32} color="#94a3b8" />
              <Text style={styles.emptyCardTitle}>No Ticket Rules Configured</Text>
              <Text style={styles.emptyCardSub}>
                Add your tours (e.g. Hallstatt Salt Mine & Skywalk) to automatically deduct €49/passenger.
              </Text>
              <TouchableOpacity
                style={styles.addFirstRuleBtn}
                onPress={() => handleOpenAddModal('Hallstatt Salt Mine')}
              >
                <Plus size={14} color="#4f46e5" />
                <Text style={styles.addFirstRuleBtnText}>Add Hallstatt Salt Mine (€49)</Text>
              </TouchableOpacity>
            </View>
          ) : (
            rules.map((rule) => {
              // Count matching bookings
              const matchCount = bookings.filter((b) =>
                b.tourTitle?.toLowerCase().includes(rule.tourKeyword.toLowerCase())
              ).length;

              return (
                <View
                  key={rule.id}
                  style={[styles.ruleCard, !rule.isEnabled && styles.ruleCardDisabled]}
                >
                  <View style={styles.ruleCardTop}>
                    <View style={styles.ruleTitleGroup}>
                      <View style={styles.ruleIconCircle}>
                        <Ticket size={16} color="#d97706" />
                      </View>
                      <View style={styles.ruleTitleTextWrap}>
                        <Text style={styles.ruleTourTitle} numberOfLines={1}>
                          {rule.tourKeyword}
                        </Text>
                        <Text style={styles.ruleSubText}>
                          {rule.description || `Rule for ${rule.tourKeyword}`}
                        </Text>
                      </View>
                    </View>

                    <Switch
                      value={rule.isEnabled}
                      onValueChange={() => handleToggleRule(rule.id)}
                      trackColor={{ false: '#cbd5e1', true: '#10b981' }}
                      thumbColor="#ffffff"
                    />
                  </View>

                  {/* Deduction details strip */}
                  <View style={styles.ruleDeductionStrip}>
                    <View style={styles.rateBadge}>
                      <Text style={styles.rateBadgeLabel}>Deduction:</Text>
                      <Text style={styles.rateBadgeValue}>
                        €{rule.ticketCostPerPassenger.toFixed(2)} / passenger
                      </Text>
                    </View>

                    {rule.fixedBookingCost ? (
                      <View style={styles.fixedBadge}>
                        <Text style={styles.fixedBadgeText}>
                          + €{rule.fixedBookingCost.toFixed(2)} fixed
                        </Text>
                      </View>
                    ) : null}

                    <View style={styles.matchCountPill}>
                      <Text style={styles.matchCountText}>
                        {matchCount} {matchCount === 1 ? 'tour matches' : 'tours match'}
                      </Text>
                    </View>
                  </View>

                  {/* Rule Footer Actions */}
                  <View style={styles.ruleFooter}>
                    <Text style={styles.ruleStatusText}>
                      {rule.isEnabled ? '✅ Auto-deducting from payouts' : '⏸️ Currently paused'}
                    </Text>

                    <TouchableOpacity
                      style={styles.deleteRuleBtn}
                      onPress={() => handleDeleteRule(rule)}
                      activeOpacity={0.7}
                    >
                      <Trash2 size={13} color="#ef4444" />
                      <Text style={styles.deleteRuleBtnText}>Delete</Text>
                    </TouchableOpacity>
                  </View>
                </View>
              );
            })
          )}

          {/* Suggestions from existing tours */}
          {existingTourTitles.length > 0 && (
            <View style={styles.suggestionsCard}>
              <View style={styles.suggestionsHeader}>
                <Sparkles size={14} color="#6366f1" />
                <Text style={styles.suggestionsTitle}>Your Current Tours (Tap to Add Rule):</Text>
              </View>
              <View style={styles.tourChipsWrap}>
                {existingTourTitles.slice(0, 6).map((title, i) => (
                  <TouchableOpacity
                    key={i}
                    style={styles.tourChip}
                    onPress={() => handleOpenAddModal(title)}
                    activeOpacity={0.7}
                  >
                    <Plus size={11} color="#4338ca" />
                    <Text style={styles.tourChipText} numberOfLines={1}>
                      {title}
                    </Text>
                  </TouchableOpacity>
                ))}
              </View>
            </View>
          )}
        </View>
      )}

      {/* TAB 2: CREDENTIALS & SYNC */}
      {activeTab === 'credentials' && (
        <View style={styles.tabContent}>
          {/* Cloud API Card */}
          <View style={styles.card}>
            <View style={styles.cardTitleRow}>
              <Globe size={16} color="#4f46e5" />
              <Text style={styles.cardTitle}>Cloud API Endpoint</Text>
            </View>
            <Text style={styles.cardDesc}>
              Live production server on Vercel managing Zoho IMAP & Gemini AI.
            </Text>
            <TextInput
              value={apiUrl}
              onChangeText={setApiUrl}
              placeholder="https://review-app-seven-kappa.vercel.app"
              placeholderTextColor="#94a3b8"
              style={styles.input}
              autoCapitalize="none"
              autoCorrect={false}
            />
          </View>

          {/* Zoho IMAP Card */}
          <View style={styles.card}>
            <View style={styles.cardTitleRow}>
              <Mail size={16} color="#059669" />
              <Text style={styles.cardTitle}>Zoho Mail Credentials (Optional Override)</Text>
            </View>
            <Text style={styles.cardDesc}>
              Default credentials are pre-configured securely on the Vercel backend. Override only
              if needed.
            </Text>

            <Text style={styles.label}>Zoho Email</Text>
            <TextInput
              value={zohoEmail}
              onChangeText={setZohoEmail}
              placeholder="bookings@alpinetourssalzburg.com"
              placeholderTextColor="#94a3b8"
              style={styles.input}
              autoCapitalize="none"
              keyboardType="email-address"
            />

            <Text style={styles.label}>App-Specific Password</Text>
            <TextInput
              value={zohoPassword}
              onChangeText={setZohoPassword}
              placeholder="••••••••••••"
              placeholderTextColor="#94a3b8"
              secureTextEntry
              style={styles.input}
              autoCapitalize="none"
            />

            <Text style={styles.label}>IMAP Host</Text>
            <TextInput
              value={zohoHost}
              onChangeText={setZohoHost}
              placeholder="imappro.zoho.eu"
              placeholderTextColor="#94a3b8"
              style={styles.input}
              autoCapitalize="none"
            />
          </View>

          {/* Gemini AI Card */}
          <View style={styles.card}>
            <View style={styles.cardTitleRow}>
              <Key size={16} color="#d97706" />
              <Text style={styles.cardTitle}>Custom Google Gemini API Key</Text>
            </View>
            <Text style={styles.cardDesc}>
              Server key is used by default. Enter a custom key to use your own Gemini quota.
            </Text>
            <TextInput
              value={geminiKey}
              onChangeText={setGeminiKey}
              placeholder="AIzaSy..."
              placeholderTextColor="#94a3b8"
              secureTextEntry
              style={styles.input}
              autoCapitalize="none"
            />
          </View>

          {/* Action Buttons */}
          <View style={styles.btnRow}>
            <TouchableOpacity
              style={styles.testBtn}
              onPress={handleTestConnection}
              disabled={isTesting}
              activeOpacity={0.8}
            >
              {isTesting ? (
                <ActivityIndicator size="small" color="#4f46e5" />
              ) : (
                <>
                  <RefreshCw size={15} color="#4f46e5" />
                  <Text style={styles.testBtnText}>Test Sync</Text>
                </>
              )}
            </TouchableOpacity>

            <TouchableOpacity
              style={[styles.saveBtn, saveSuccess && styles.saveBtnSuccess]}
              onPress={handleSave}
              activeOpacity={0.8}
            >
              {saveSuccess ? (
                <>
                  <Check size={16} color="#ffffff" />
                  <Text style={styles.saveBtnText}>Saved!</Text>
                </>
              ) : (
                <Text style={styles.saveBtnText}>Save Settings</Text>
              )}
            </TouchableOpacity>
          </View>
        </View>
      )}

      {/* Add / Edit Ticket Rule Modal */}
      <Modal visible={modalVisible} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <View style={styles.modalHeaderLeft}>
                <Ticket size={20} color="#d97706" />
                <Text style={styles.modalTitle}>Set Tour Ticket Deduction</Text>
              </View>
              <TouchableOpacity onPress={() => setModalVisible(false)} activeOpacity={0.7}>
                <X size={20} color="#64748b" />
              </TouchableOpacity>
            </View>

            <Text style={styles.modalSub}>
              Enter tour title keywords and the admission ticket cost per passenger. The app will
              automatically deduct it whenever this tour appears in your bookings!
            </Text>

            {/* Tour Title Input */}
            <Text style={styles.modalInputLabel}>Tour Title / Keyword *</Text>
            <TextInput
              style={styles.modalInput}
              value={tourKeyword}
              onChangeText={setTourKeyword}
              placeholder="e.g. Hallstatt Salt Mine"
              placeholderTextColor="#94a3b8"
            />

            {/* Ticket Cost Per Passenger Input */}
            <Text style={styles.modalInputLabel}>Ticket Cost Per Passenger (€) *</Text>
            <TextInput
              style={styles.modalInput}
              value={ticketCostText}
              onChangeText={setTicketCostText}
              placeholder="49.00"
              keyboardType="numeric"
              placeholderTextColor="#94a3b8"
            />

            {/* Optional Fixed Cost */}
            <Text style={styles.modalInputLabel}>Optional Fixed Tour Fee (€)</Text>
            <TextInput
              style={styles.modalInput}
              value={fixedCostText}
              onChangeText={setFixedCostText}
              placeholder="0.00 (Leave empty if none)"
              keyboardType="numeric"
              placeholderTextColor="#94a3b8"
            />

            {/* Description / Notes */}
            <Text style={styles.modalInputLabel}>Notes / Description</Text>
            <TextInput
              style={styles.modalInput}
              value={descriptionText}
              onChangeText={setDescriptionText}
              placeholder="e.g. Adult Salt Mine entrance ticket"
              placeholderTextColor="#94a3b8"
            />

            <View style={styles.modalBtnRow}>
              <TouchableOpacity
                style={styles.cancelModalBtn}
                onPress={() => setModalVisible(false)}
                activeOpacity={0.7}
              >
                <Text style={styles.cancelModalBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.saveModalBtn}
                onPress={handleSaveRule}
                activeOpacity={0.8}
              >
                <Check size={16} color="#ffffff" />
                <Text style={styles.saveModalBtnText}>Save Rule</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  content: {
    padding: 16,
    paddingBottom: 40,
    gap: 14,
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 4,
  },
  headerIcon: {
    width: 40,
    height: 40,
    borderRadius: 12,
    backgroundColor: '#4f46e5',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontSize: 20,
    fontWeight: '800',
    color: '#0f172a',
  },
  subtitle: {
    fontSize: 12,
    color: '#64748b',
    marginTop: 2,
  },
  tabContainer: {
    flexDirection: 'row',
    backgroundColor: '#e2e8f0',
    borderRadius: 12,
    padding: 3,
    marginBottom: 6,
  },
  tabBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 10,
    borderRadius: 10,
  },
  tabBtnActive: {
    backgroundColor: '#4f46e5',
    shadowColor: '#4f46e5',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 3,
  },
  tabBtnText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#64748b',
  },
  tabBtnTextActive: {
    color: '#ffffff',
  },
  tabContent: {
    gap: 14,
  },
  infoBanner: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: 8,
    backgroundColor: '#f0f9ff',
    borderRadius: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: '#bae6fd',
  },
  infoBannerText: {
    flex: 1,
    fontSize: 12,
    color: '#0369a1',
    lineHeight: 18,
  },
  boldText: {
    fontWeight: '800',
    color: '#0284c7',
  },
  sectionHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 4,
  },
  sectionTitle: {
    fontSize: 15,
    fontWeight: '800',
    color: '#1e293b',
  },
  addRuleBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#4f46e5',
    paddingHorizontal: 12,
    paddingVertical: 7,
    borderRadius: 10,
  },
  addRuleBtnText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#ffffff',
  },
  ruleCard: {
    backgroundColor: '#ffffff',
    borderRadius: 14,
    padding: 14,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
    gap: 10,
  },
  ruleCardDisabled: {
    opacity: 0.6,
    backgroundColor: '#f8fafc',
  },
  ruleCardTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  ruleTitleGroup: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
    marginRight: 10,
  },
  ruleIconCircle: {
    width: 34,
    height: 34,
    borderRadius: 17,
    backgroundColor: '#fef3c7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  ruleTitleTextWrap: {
    flex: 1,
  },
  ruleTourTitle: {
    fontSize: 14,
    fontWeight: '800',
    color: '#1e293b',
  },
  ruleSubText: {
    fontSize: 11,
    color: '#64748b',
    marginTop: 1,
  },
  ruleDeductionStrip: {
    flexDirection: 'row',
    alignItems: 'center',
    flexWrap: 'wrap',
    gap: 6,
  },
  rateBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#fffbeb',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#fde68a',
  },
  rateBadgeLabel: {
    fontSize: 11,
    fontWeight: '600',
    color: '#92400e',
  },
  rateBadgeValue: {
    fontSize: 12,
    fontWeight: '900',
    color: '#b45309',
  },
  fixedBadge: {
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  fixedBadgeText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#475569',
  },
  matchCountPill: {
    backgroundColor: '#eff6ff',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 8,
  },
  matchCountText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#2563eb',
  },
  ruleFooter: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    borderTopWidth: 1,
    borderTopColor: '#f1f5f9',
    paddingTop: 8,
    marginTop: 2,
  },
  ruleStatusText: {
    fontSize: 11,
    color: '#64748b',
    fontWeight: '600',
  },
  deleteRuleBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: 4,
    paddingHorizontal: 8,
    borderRadius: 6,
    backgroundColor: '#fef2f2',
  },
  deleteRuleBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#ef4444',
  },
  emptyCard: {
    backgroundColor: '#ffffff',
    borderRadius: 14,
    padding: 24,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#e2e8f0',
    gap: 8,
  },
  emptyCardTitle: {
    fontSize: 15,
    fontWeight: '800',
    color: '#334155',
  },
  emptyCardSub: {
    fontSize: 12,
    color: '#64748b',
    textAlign: 'center',
    maxWidth: 260,
  },
  addFirstRuleBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#eff6ff',
    paddingHorizontal: 14,
    paddingVertical: 8,
    borderRadius: 10,
    marginTop: 6,
  },
  addFirstRuleBtnText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#4f46e5',
  },
  suggestionsCard: {
    backgroundColor: '#f5f3ff',
    borderRadius: 14,
    padding: 12,
    borderWidth: 1,
    borderColor: '#ddd6fe',
    gap: 8,
  },
  suggestionsHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  suggestionsTitle: {
    fontSize: 12,
    fontWeight: '800',
    color: '#4338ca',
  },
  tourChipsWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  tourChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#ffffff',
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 5,
    borderWidth: 1,
    borderColor: '#c7d2fe',
    maxWidth: '100%',
  },
  tourChipText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#3730a3',
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 14,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 3,
  },
  cardTitleRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 4,
  },
  cardTitle: {
    fontSize: 15,
    fontWeight: '800',
    color: '#0f172a',
  },
  cardDesc: {
    fontSize: 12,
    color: '#64748b',
    lineHeight: 17,
    marginBottom: 12,
  },
  label: {
    fontSize: 12,
    fontWeight: '700',
    color: '#334155',
    marginBottom: 4,
    marginTop: 8,
  },
  input: {
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 13,
    color: '#0f172a',
  },
  btnRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 8,
  },
  testBtn: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#ffffff',
    borderWidth: 1.5,
    borderColor: '#4f46e5',
    borderRadius: 12,
    paddingVertical: 12,
  },
  testBtnText: {
    fontSize: 14,
    fontWeight: '700',
    color: '#4f46e5',
  },
  saveBtn: {
    flex: 2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#4f46e5',
    borderRadius: 12,
    paddingVertical: 12,
    shadowColor: '#4f46e5',
    shadowOffset: { width: 0, height: 3 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
  },
  saveBtnSuccess: {
    backgroundColor: '#059669',
  },
  saveBtnText: {
    fontSize: 14,
    fontWeight: '700',
    color: '#ffffff',
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    justifyContent: 'center',
    padding: 20,
  },
  modalContent: {
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 20,
    gap: 10,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 10 },
    shadowOpacity: 0.25,
    shadowRadius: 15,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  modalHeaderLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  modalTitle: {
    fontSize: 17,
    fontWeight: '800',
    color: '#0f172a',
  },
  modalSub: {
    fontSize: 12,
    color: '#64748b',
    lineHeight: 17,
  },
  modalInputLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#334155',
    marginTop: 4,
  },
  modalInput: {
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 13,
    color: '#0f172a',
  },
  modalBtnRow: {
    flexDirection: 'row',
    gap: 10,
    marginTop: 12,
  },
  cancelModalBtn: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingVertical: 12,
    borderRadius: 12,
    backgroundColor: '#f1f5f9',
  },
  cancelModalBtnText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#64748b',
  },
  saveModalBtn: {
    flex: 2,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 12,
    borderRadius: 12,
    backgroundColor: '#4f46e5',
  },
  saveModalBtnText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#ffffff',
  },
});

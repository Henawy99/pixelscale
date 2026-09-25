import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TouchableOpacity,
  ScrollView,
  TextInput,
  Modal,
  Alert,
  Linking,
} from 'react-native';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import {
  Compass,
  Plus,
  ExternalLink,
  Trash2,
  Sparkles,
  Link2,
  MapPin,
  Ticket,
  X,
  ClipboardPaste,
  Check,
} from 'lucide-react-native';
import { OfferedTour } from '../types';
import {
  saveOfferedTour,
  deleteOfferedTour,
  extractTitleFromGygUrl,
} from '../lib/toursStorage';

interface ToursScreenProps {
  tours: OfferedTour[];
  onToursUpdated: () => Promise<void> | void;
  onGenerateReviewForTour: (tour: OfferedTour) => void;
}

export function ToursScreen({
  tours = [],
  onToursUpdated,
  onGenerateReviewForTour,
}: ToursScreenProps) {
  const [modalVisible, setModalVisible] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

  const [url, setUrl] = useState('');
  const [title, setTitle] = useState('');
  const [location, setLocation] = useState('');
  const [ticketCostText, setTicketCostText] = useState('');
  const [notes, setNotes] = useState('');

  const handleOpenAdd = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setEditingId(null);
    setUrl('');
    setTitle('');
    setLocation('');
    setTicketCostText('');
    setNotes('');
    setModalVisible(true);
  };

  const handlePasteUrl = async () => {
    Haptics.selectionAsync();
    const clip = await Clipboard.getStringAsync();
    if (clip && (clip.includes('getyourguide.com') || clip.startsWith('http'))) {
      setUrl(clip.trim());
      const extracted = extractTitleFromGygUrl(clip.trim());
      if (extracted.title && !title) setTitle(extracted.title);
      if (extracted.location && !location) setLocation(extracted.location);
    } else {
      Alert.alert('Clipboard Empty', 'Please copy a valid GetYourGuide link first.');
    }
  };

  const handleUrlChange = (text: string) => {
    setUrl(text);
    if (text.includes('getyourguide.com') && !title) {
      const extracted = extractTitleFromGygUrl(text);
      if (extracted.title) setTitle(extracted.title);
      if (extracted.location && !location) setLocation(extracted.location);
    }
  };

  const handleSaveTour = async () => {
    if (!url.trim()) {
      Alert.alert('URL Required', 'Please enter or paste a GetYourGuide tour link.');
      return;
    }

    const extracted = extractTitleFromGygUrl(url.trim());
    const finalTitle = title.trim() || extracted.title || 'My GetYourGuide Tour';

    const ticketNum = parseFloat(ticketCostText.replace(',', '.'));
    const ticketCost = !isNaN(ticketNum) && ticketNum >= 0 ? ticketNum : undefined;

    const newTour: OfferedTour = {
      id: editingId || `tour_${Date.now()}`,
      title: finalTitle,
      gygUrl: url.trim(),
      location: location.trim() || extracted.location || undefined,
      ticketCostPerPassenger: ticketCost,
      notes: notes.trim() || undefined,
      createdAt: Date.now(),
    };

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await saveOfferedTour(newTour);
    if (onToursUpdated) await onToursUpdated();
    setModalVisible(false);
  };

  const handleDeleteTour = (tour: OfferedTour) => {
    Alert.alert(
      'Delete Tour',
      `Are you sure you want to remove "${tour.title}" from your offered tours?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
            await deleteOfferedTour(tour.id);
            if (onToursUpdated) await onToursUpdated();
          },
        },
      ]
    );
  };

  const handleOpenGygUrl = (gygUrl: string) => {
    if (gygUrl) {
      Linking.openURL(gygUrl);
    }
  };

  const handleGenerate = (tour: OfferedTour) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    onGenerateReviewForTour(tour);
  };

  return (
    <View style={styles.container}>
      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Header */}
        <View style={styles.headerRow}>
          <View style={styles.headerLeft}>
            <View style={styles.headerIcon}>
              <Compass size={22} color="#ffffff" />
            </View>
            <View>
              <Text style={styles.headerTitle}>Offered Tours</Text>
              <Text style={styles.headerSubtitle}>
                {tours.length} tour{tours.length === 1 ? '' : 's'} saved · Ready for 1-tap review generation
              </Text>
            </View>
          </View>

          <TouchableOpacity
            style={styles.addTourBtn}
            onPress={handleOpenAdd}
            activeOpacity={0.8}
          >
            <Plus size={16} color="#ffffff" />
            <Text style={styles.addTourBtnText}>Add Tour</Text>
          </TouchableOpacity>
        </View>

        {/* Empty State */}
        {tours.length === 0 ? (
          <View style={styles.emptyCard}>
            <Compass size={48} color="#94a3b8" />
            <Text style={styles.emptyTitle}>No Offered Tours Added</Text>
            <Text style={styles.emptySubtitle}>
              Paste your GetYourGuide tour link so the app knows which tours you offer. You will never need to type or paste the tour link again when generating reviews!
            </Text>
            <TouchableOpacity
              style={styles.emptyActionBtn}
              onPress={handleOpenAdd}
              activeOpacity={0.8}
            >
              <Plus size={16} color="#ffffff" />
              <Text style={styles.emptyActionBtnText}>Paste Tour Link</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <View style={styles.toursList}>
            {tours.map((t) => (
              <View key={t.id} style={styles.tourCard}>
                {/* Title & Delete */}
                <View style={styles.tourCardTop}>
                  <Text style={styles.tourTitle} numberOfLines={2}>
                    {t.title}
                  </Text>
                  <TouchableOpacity
                    onPress={() => handleDeleteTour(t)}
                    hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
                    style={styles.deleteBtn}
                  >
                    <Trash2 size={16} color="#ef4444" />
                  </TouchableOpacity>
                </View>

                {/* Badges: Location & Ticket Cost */}
                <View style={styles.badgesRow}>
                  {t.location ? (
                    <View style={styles.locationBadge}>
                      <MapPin size={11} color="#0369a1" />
                      <Text style={styles.locationBadgeText}>{t.location}</Text>
                    </View>
                  ) : null}

                  {typeof t.ticketCostPerPassenger === 'number' && t.ticketCostPerPassenger > 0 ? (
                    <View style={styles.ticketBadge}>
                      <Ticket size={11} color="#b45309" />
                      <Text style={styles.ticketBadgeText}>
                        Tickets: €{t.ticketCostPerPassenger}/person
                      </Text>
                    </View>
                  ) : null}
                </View>

                {/* Notes if any */}
                {t.notes ? (
                  <Text style={styles.tourNotes} numberOfLines={2}>
                    {t.notes}
                  </Text>
                ) : null}

                {/* Link Row */}
                <TouchableOpacity
                  style={styles.urlRow}
                  onPress={() => handleOpenGygUrl(t.gygUrl)}
                  activeOpacity={0.7}
                >
                  <Link2 size={13} color="#2563eb" />
                  <Text style={styles.urlText} numberOfLines={1}>
                    {t.gygUrl}
                  </Text>
                  <ExternalLink size={12} color="#2563eb" />
                </TouchableOpacity>

                {/* Bottom Action: Generate Review */}
                <TouchableOpacity
                  style={styles.generateReviewBtn}
                  onPress={() => handleGenerate(t)}
                  activeOpacity={0.8}
                >
                  <Sparkles size={14} color="#ffffff" />
                  <Text style={styles.generateReviewBtnText}>
                    Generate 5★ Review for This Tour
                  </Text>
                </TouchableOpacity>
              </View>
            ))}
          </View>
        )}
      </ScrollView>

      {/* Add Tour Modal */}
      <Modal visible={modalVisible} transparent animationType="fade">
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setModalVisible(false)}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Add GetYourGuide Tour</Text>
              <TouchableOpacity onPress={() => setModalVisible(false)}>
                <X size={18} color="#64748b" />
              </TouchableOpacity>
            </View>

            <Text style={styles.modalSub}>
              Paste your tour link. The app will automatically remember this tour for instant review generation.
            </Text>

            {/* URL Input with Paste Button */}
            <Text style={styles.fieldLabel}>GetYourGuide Tour URL *</Text>
            <View style={styles.urlInputRow}>
              <TextInput
                style={styles.urlInput}
                placeholder="https://www.getyourguide.com/..."
                placeholderTextColor="#94a3b8"
                value={url}
                onChangeText={handleUrlChange}
                autoCapitalize="none"
                autoCorrect={false}
              />
              <TouchableOpacity
                style={styles.pasteBtn}
                onPress={handlePasteUrl}
                activeOpacity={0.7}
              >
                <ClipboardPaste size={14} color="#4f46e5" />
                <Text style={styles.pasteBtnText}>Paste</Text>
              </TouchableOpacity>
            </View>

            {/* Tour Title */}
            <Text style={styles.fieldLabel}>Tour Title *</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="e.g. Hallstatt Salt Mine & Skywalk Private Tour"
              placeholderTextColor="#94a3b8"
              value={title}
              onChangeText={setTitle}
            />

            {/* Location */}
            <Text style={styles.fieldLabel}>Location (Optional)</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="e.g. Salzburg / Hallstatt"
              placeholderTextColor="#94a3b8"
              value={location}
              onChangeText={setLocation}
            />

            {/* Ticket Cost Per Passenger */}
            <Text style={styles.fieldLabel}>Ticket Cost Per Passenger (€ Optional)</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="e.g. 49"
              placeholderTextColor="#94a3b8"
              keyboardType="numeric"
              value={ticketCostText}
              onChangeText={setTicketCostText}
            />

            {/* Notes */}
            <Text style={styles.fieldLabel}>Tour Details / Notes (Optional)</Text>
            <TextInput
              style={[styles.modalInput, styles.notesInput]}
              placeholder="e.g. Private minivan tour, includes funicular, great mountain views"
              placeholderTextColor="#94a3b8"
              value={notes}
              onChangeText={setNotes}
              multiline
              numberOfLines={2}
            />

            {/* Save Button */}
            <TouchableOpacity
              style={styles.saveBtn}
              onPress={handleSaveTour}
              activeOpacity={0.8}
            >
              <Check size={16} color="#ffffff" />
              <Text style={styles.saveBtnText}>Save Tour</Text>
            </TouchableOpacity>
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
  scrollContent: {
    padding: 16,
    paddingBottom: 40,
  },
  headerRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  headerLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    flex: 1,
  },
  headerIcon: {
    width: 42,
    height: 42,
    borderRadius: 12,
    backgroundColor: '#0284c7',
    alignItems: 'center',
    justifyContent: 'center',
  },
  headerTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0f172a',
  },
  headerSubtitle: {
    fontSize: 11,
    color: '#64748b',
    marginTop: 2,
    maxWidth: 220,
  },
  addTourBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    backgroundColor: '#0284c7',
    paddingHorizontal: 12,
    paddingVertical: 9,
    borderRadius: 10,
  },
  addTourBtnText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#ffffff',
  },
  emptyCard: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#ffffff',
    borderRadius: 18,
    padding: 30,
    marginTop: 20,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  emptyTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#334155',
    marginTop: 14,
  },
  emptySubtitle: {
    fontSize: 12,
    color: '#64748b',
    textAlign: 'center',
    marginTop: 8,
    lineHeight: 18,
  },
  emptyActionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#0284c7',
    paddingHorizontal: 16,
    paddingVertical: 10,
    borderRadius: 12,
    marginTop: 18,
  },
  emptyActionBtnText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#ffffff',
  },
  toursList: {
    gap: 12,
  },
  tourCard: {
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 6,
  },
  tourCardTop: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    justifyContent: 'space-between',
    marginBottom: 8,
    gap: 10,
  },
  tourTitle: {
    fontSize: 15,
    fontWeight: '800',
    color: '#0f172a',
    lineHeight: 20,
    flex: 1,
  },
  deleteBtn: {
    padding: 4,
  },
  badgesRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
    marginBottom: 8,
  },
  locationBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#f0f9ff',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#bae6fd',
  },
  locationBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#0369a1',
  },
  ticketBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#fef3c7',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#fde68a',
  },
  ticketBadgeText: {
    fontSize: 10,
    fontWeight: '700',
    color: '#b45309',
  },
  tourNotes: {
    fontSize: 12,
    color: '#64748b',
    marginBottom: 10,
    lineHeight: 16,
  },
  urlRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#f8fafc',
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 8,
    marginBottom: 12,
  },
  urlText: {
    fontSize: 11,
    color: '#2563eb',
    fontWeight: '600',
    flex: 1,
  },
  generateReviewBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 7,
    backgroundColor: '#4f46e5',
    paddingVertical: 10,
    borderRadius: 12,
    shadowColor: '#4f46e5',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.2,
    shadowRadius: 4,
  },
  generateReviewBtnText: {
    fontSize: 12,
    fontWeight: '800',
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
    maxHeight: 520,
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
    marginBottom: 14,
    lineHeight: 16,
  },
  fieldLabel: {
    fontSize: 11,
    fontWeight: '700',
    color: '#334155',
    marginBottom: 5,
  },
  urlInputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    marginBottom: 12,
  },
  urlInput: {
    flex: 1,
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 10,
    paddingHorizontal: 10,
    paddingVertical: 8,
    fontSize: 12,
    color: '#0f172a',
  },
  pasteBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#eef2ff',
    paddingHorizontal: 10,
    paddingVertical: 8,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#c7d2fe',
  },
  pasteBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#4f46e5',
  },
  modalInput: {
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 8,
    fontSize: 13,
    color: '#0f172a',
    marginBottom: 12,
  },
  notesInput: {
    minHeight: 50,
  },
  saveBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#0284c7',
    paddingVertical: 12,
    borderRadius: 12,
    marginTop: 6,
    shadowColor: '#0284c7',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  saveBtnText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#ffffff',
  },
});

import React, { useState } from 'react';
import {
  View,
  Text,
  StyleSheet,
  TextInput,
  TouchableOpacity,
  ScrollView,
  Image,
  ActivityIndicator,
  Modal,
  Alert,
  FlatList,
} from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import {
  Sparkles,
  Link,
  Copy,
  Check,
  Star,
  ExternalLink,
  X,
  Share2,
  Users,
  UserPlus,
  Trash2,
  Phone,
  MessageCircle,
  CheckCircle2,
  ArrowRight,
} from 'lucide-react-native';
import {
  ReviewTone,
  AnalyzeResponse,
  PhotoItem,
  Reviewer,
  ReviewerAssignment,
  BookingItem,
  isBookingReview,
} from '../types';
import { analyzeTourRequest } from '../api/client';
import {
  saveReviewer,
  deleteReviewer,
  shareToWhatsApp,
  formatWhatsAppReviewMessage,
} from '../lib/reviewerStorage';

interface StudioScreenProps {
  prefilledUrl?: string;
  prefilledNotes?: string;
  onClearPrefill?: () => void;
  onSaveToHistory?: (result: AnalyzeResponse) => void;
  reviewers?: Reviewer[];
  reviewerAssignments?: Record<string, ReviewerAssignment>;
  bookings?: BookingItem[];
  onReviewersUpdated?: () => Promise<void> | void;
  onAssignReviewer?: (
    bookingRef: string,
    reviewerId: string,
    reviewText?: string,
    photoUrls?: string[],
    notes?: string
  ) => void;
}

const COLOR_PALETTE = [
  '#10b981', // emerald
  '#3b82f6', // blue
  '#8b5cf6', // purple
  '#ec4899', // pink
  '#f59e0b', // amber
  '#06b6d4', // cyan
];

export function StudioScreen({
  prefilledUrl = '',
  prefilledNotes = '',
  onClearPrefill,
  onSaveToHistory,
  reviewers = [],
  reviewerAssignments = {},
  bookings = [],
  onReviewersUpdated,
  onAssignReviewer,
}: StudioScreenProps) {
  // Segmented top tab
  const [subTab, setSubTab] = useState<'people' | 'studio'>(
    prefilledUrl ? 'studio' : 'people'
  );

  // Review People State
  const [addModalVisible, setAddModalVisible] = useState(false);
  const [newReviewerName, setNewReviewerName] = useState('');
  const [newReviewerPhone, setNewReviewerPhone] = useState('');
  const [newReviewerNotes, setNewReviewerNotes] = useState('');
  const [newReviewerColor, setNewReviewerColor] = useState(COLOR_PALETTE[0]);
  const [editingReviewerId, setEditingReviewerId] = useState<string | null>(null);

  // AI Studio State
  const [url, setUrl] = useState(prefilledUrl);
  const [notes, setNotes] = useState(prefilledNotes);
  const [selectedTone, setSelectedTone] = useState<ReviewTone>('balanced');
  const [isGenerating, setIsGenerating] = useState(false);
  const [result, setResult] = useState<AnalyzeResponse | null>(null);
  const [copiedReview, setCopiedReview] = useState(false);
  const [selectedPhoto, setSelectedPhoto] = useState<PhotoItem | null>(null);
  const [attachModalVisible, setAttachModalVisible] = useState(false);

  // Only review bookings (< €30) for assignment
  const reviewBookings = bookings.filter((b) => b.status !== 'cancelled' && isBookingReview(b));

  const tones: { key: ReviewTone; label: string; desc: string }[] = [
    { key: 'balanced', label: 'Balanced', desc: 'Authentic & helpful' },
    { key: 'enthusiastic', label: 'Enthusiastic', desc: '5-star excited' },
    { key: 'detailed', label: 'Detailed', desc: 'In-depth itinerary' },
    { key: 'casual', label: 'Casual', desc: 'Friendly traveler' },
    { key: 'punchy', label: 'Punchy', desc: 'Short & memorable' },
  ];

  // Open add reviewer modal
  const handleOpenAddReviewer = () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    setEditingReviewerId(null);
    setNewReviewerName('');
    setNewReviewerPhone('');
    setNewReviewerNotes('');
    setNewReviewerColor(COLOR_PALETTE[Math.floor(Math.random() * COLOR_PALETTE.length)]);
    setAddModalVisible(true);
  };

  // Save or edit reviewer
  const handleSaveReviewer = async () => {
    if (!newReviewerName.trim()) {
      Alert.alert('Name Required', 'Please enter a name for the reviewer.');
      return;
    }

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    const newRev: Reviewer = {
      id: editingReviewerId || `rev_${Date.now()}`,
      name: newReviewerName.trim(),
      phone: newReviewerPhone.trim(),
      whatsappPhone: newReviewerPhone.trim(),
      color: newReviewerColor,
      notes: newReviewerNotes.trim() || undefined,
      createdAt: Date.now(),
    };

    await saveReviewer(newRev);
    if (onReviewersUpdated) await onReviewersUpdated();
    setAddModalVisible(false);
  };

  // Delete reviewer
  const handleDeleteReviewer = (rev: Reviewer) => {
    Alert.alert(
      'Delete Reviewer',
      `Are you sure you want to remove "${rev.name}" from your Review People list?`,
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
            await deleteReviewer(rev.id);
            if (onReviewersUpdated) await onReviewersUpdated();
          },
        },
      ]
    );
  };

  // Direct WhatsApp chat from reviewer card
  const handleChatReviewer = async (rev: Reviewer) => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Light);
    const phone = rev.whatsappPhone || rev.phone;
    if (!phone) {
      Alert.alert('No Phone', `Please add a phone number for ${rev.name} to chat via WhatsApp.`);
      return;
    }
    const msg = `Hi ${rev.name}! We have some new tour reviews to organize.`;
    await shareToWhatsApp(phone, msg);
  };

  // AI Generate Handler
  const handleGenerate = async () => {
    if (!url.trim()) {
      Alert.alert('Tour Required', 'Please enter a GetYourGuide tour link or tour name.');
      return;
    }

    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setIsGenerating(true);
    setResult(null);

    try {
      const res = await analyzeTourRequest({
        url: url.trim(),
        tone: selectedTone,
        customNotes: notes.trim() || undefined,
      });

      if (!res.success || res.error) {
        Alert.alert('Generation Notice', res.error || 'Failed to generate review. Check your API key.');
      } else {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        setResult(res);
        if (onSaveToHistory) onSaveToHistory(res);
      }
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'Network error occurred';
      Alert.alert('Error', msg);
    } finally {
      setIsGenerating(false);
    }
  };

  const handleCopyReview = async () => {
    if (!result?.review?.text) return;
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await Clipboard.setStringAsync(result.review.text);
    setCopiedReview(true);
    setTimeout(() => setCopiedReview(false), 2000);
  };

  // Attach generated review & photos to a booking
  const handleAttachToBooking = (booking: BookingItem) => {
    if (!result?.review?.text) return;
    const currentAssign = reviewerAssignments[booking.referenceNumber];
    const reviewerId = currentAssign?.reviewerId || (reviewers[0] ? reviewers[0].id : '');

    const photoUrls = (result.photos || []).map((p) => p.url).filter(Boolean);

    if (onAssignReviewer) {
      onAssignReviewer(
        booking.referenceNumber,
        reviewerId,
        result.review.text,
        photoUrls,
        result.review.headline
      );
    }

    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setAttachModalVisible(false);
    Alert.alert(
      'Attached to Booking',
      `Successfully attached review & ${photoUrls.length} photos to booking ${booking.referenceNumber}!`
    );
  };

  // Get assigned bookings count for a reviewer
  const getAssignedBookingsForReviewer = (reviewerId: string) => {
    return Object.values(reviewerAssignments).filter((a) => a.reviewerId === reviewerId);
  };

  return (
    <View style={styles.container}>
      {/* Segmented Tab Navigation: Review People vs AI Studio */}
      <View style={styles.subTabBar}>
        <TouchableOpacity
          style={[styles.subTabButton, subTab === 'people' && styles.subTabButtonActive]}
          onPress={() => {
            Haptics.selectionAsync();
            setSubTab('people');
          }}
          activeOpacity={0.7}
        >
          <Users size={16} color={subTab === 'people' ? '#059669' : '#64748b'} />
          <Text
            style={[
              styles.subTabButtonText,
              subTab === 'people' && styles.subTabButtonTextActive,
            ]}
          >
            Review People ({reviewers.length})
          </Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.subTabButton, subTab === 'studio' && styles.subTabButtonActiveStudio]}
          onPress={() => {
            Haptics.selectionAsync();
            setSubTab('studio');
          }}
          activeOpacity={0.7}
        >
          <Sparkles size={16} color={subTab === 'studio' ? '#4f46e5' : '#64748b'} />
          <Text
            style={[
              styles.subTabButtonText,
              subTab === 'studio' && styles.subTabButtonTextActiveStudio,
            ]}
          >
            AI Review Studio
          </Text>
        </TouchableOpacity>
      </View>

      {/* ============================================================== */}
      {/* SUB-TAB 1: REVIEW PEOPLE LIST                                   */}
      {/* ============================================================== */}
      {subTab === 'people' && (
        <ScrollView style={styles.tabContent} contentContainerStyle={styles.scrollContent}>
          {/* Action Row */}
          <View style={styles.peopleHeaderRow}>
            <View>
              <Text style={styles.peopleTitle}>Review People</Text>
              <Text style={styles.peopleSubtitle}>
                Attach to review bookings & share text + photos via WhatsApp
              </Text>
            </View>

            <TouchableOpacity
              style={styles.addReviewerBtn}
              onPress={handleOpenAddReviewer}
              activeOpacity={0.8}
            >
              <UserPlus size={15} color="#ffffff" />
              <Text style={styles.addReviewerBtnText}>Add Person</Text>
            </TouchableOpacity>
          </View>

          {/* Reviewers List */}
          {reviewers.length === 0 ? (
            <View style={styles.emptyStateBox}>
              <Users size={44} color="#94a3b8" />
              <Text style={styles.emptyStateTitle}>No Review People Added</Text>
              <Text style={styles.emptyStateSubtitle}>
                Tap "Add Person" above to add names and WhatsApp numbers of friends, family, or reviewers.
              </Text>
            </View>
          ) : (
            <View style={styles.reviewersList}>
              {reviewers.map((rev) => {
                const assignedBookings = getAssignedBookingsForReviewer(rev.id);
                const phone = rev.whatsappPhone || rev.phone;

                return (
                  <View key={rev.id} style={styles.reviewerCard}>
                    {/* Header: Avatar, Name, Delete */}
                    <View style={styles.reviewerCardTop}>
                      <View style={styles.reviewerCardInfo}>
                        <View
                          style={[
                            styles.reviewerAvatar,
                            { backgroundColor: rev.color || '#10b981' },
                          ]}
                        >
                          <Text style={styles.reviewerAvatarInitial}>
                            {rev.name.charAt(0).toUpperCase()}
                          </Text>
                        </View>
                        <View>
                          <Text style={styles.reviewerName}>{rev.name}</Text>
                          {rev.notes ? (
                            <Text style={styles.reviewerNotes} numberOfLines={1}>
                              {rev.notes}
                            </Text>
                          ) : null}
                        </View>
                      </View>

                      <TouchableOpacity
                        style={styles.deleteRevBtn}
                        onPress={() => handleDeleteReviewer(rev)}
                        hitSlop={{ top: 10, bottom: 10, left: 10, right: 10 }}
                      >
                        <Trash2 size={16} color="#ef4444" />
                      </TouchableOpacity>
                    </View>

                    {/* Middle: Phone & WhatsApp Chat */}
                    <View style={styles.reviewerContactRow}>
                      <View style={styles.reviewerPhoneBadge}>
                        <Phone size={12} color="#059669" />
                        <Text style={styles.reviewerPhoneText}>
                          {phone || 'No phone number'}
                        </Text>
                      </View>

                      {phone ? (
                        <TouchableOpacity
                          style={styles.quickChatBtn}
                          onPress={() => handleChatReviewer(rev)}
                          activeOpacity={0.7}
                        >
                          <MessageCircle size={13} color="#25d366" />
                          <Text style={styles.quickChatBtnText}>WhatsApp Chat</Text>
                        </TouchableOpacity>
                      ) : null}
                    </View>

                    {/* Attached Bookings Tag */}
                    <View style={styles.reviewerAssignmentsRow}>
                      <Text style={styles.assignmentCountLabel}>
                        {assignedBookings.length === 0
                          ? 'No active review bookings assigned'
                          : `Attached to ${assignedBookings.length} booking${
                              assignedBookings.length === 1 ? '' : 's'
                            }:`}
                      </Text>
                      {assignedBookings.length > 0 && (
                        <View style={styles.assignedPillsList}>
                          {assignedBookings.map((a) => (
                            <View key={a.bookingRef} style={styles.bookingRefPill}>
                              <Text style={styles.bookingRefPillText}>{a.bookingRef}</Text>
                            </View>
                          ))}
                        </View>
                      )}
                    </View>
                  </View>
                );
              })}
            </View>
          )}
        </ScrollView>
      )}

      {/* ============================================================== */}
      {/* SUB-TAB 2: AI REVIEW STUDIO                                     */}
      {/* ============================================================== */}
      {subTab === 'studio' && (
        <ScrollView style={styles.tabContent} contentContainerStyle={styles.scrollContent}>
          {/* Title Header */}
          <View style={styles.header}>
            <View style={styles.headerIcon}>
              <Sparkles size={20} color="#ffffff" />
            </View>
            <View>
              <Text style={styles.title}>AI Review Studio</Text>
              <Text style={styles.subtitle}>
                Generate 5-star traveler reviews & 3 matching high-res photos
              </Text>
            </View>
          </View>

          {/* Input Card */}
          <View style={styles.card}>
            <Text style={styles.inputLabel}>GetYourGuide Tour URL or Title</Text>
            <View style={styles.inputRow}>
              <Link size={16} color="#94a3b8" />
              <TextInput
                placeholder="https://www.getyourguide.com/... or Tour Name"
                placeholderTextColor="#94a3b8"
                value={url}
                onChangeText={setUrl}
                style={styles.textInput}
                autoCapitalize="none"
                autoCorrect={false}
              />
            </View>

            {/* Tone Selector */}
            <Text style={[styles.inputLabel, { marginTop: 14 }]}>Review Tone</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} style={styles.tonesScroll}>
              {tones.map((t) => {
                const isSel = selectedTone === t.key;
                return (
                  <TouchableOpacity
                    key={t.key}
                    onPress={() => {
                      Haptics.selectionAsync();
                      setSelectedTone(t.key);
                    }}
                    style={[styles.tonePill, isSel && styles.tonePillActive]}
                    activeOpacity={0.7}
                  >
                    <Text style={[styles.toneLabel, isSel && styles.toneLabelActive]}>
                      {t.label}
                    </Text>
                    <Text style={[styles.toneDesc, isSel && styles.toneDescActive]}>
                      {t.desc}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </ScrollView>

            {/* Custom Notes */}
            <Text style={[styles.inputLabel, { marginTop: 14 }]}>
              Custom Notes / Guide Details (Optional)
            </Text>
            <TextInput
              placeholder="e.g. Highlight our friendly driver Thomas and the amazing weather at Hallstatt..."
              placeholderTextColor="#94a3b8"
              value={notes}
              onChangeText={setNotes}
              style={styles.notesInput}
              multiline
              numberOfLines={3}
            />

            {/* Generate Button */}
            <TouchableOpacity
              onPress={handleGenerate}
              disabled={isGenerating}
              activeOpacity={0.8}
              style={styles.generateBtnWrapper}
            >
              <LinearGradient
                colors={['#4f46e5', '#7c3aed']}
                start={{ x: 0, y: 0 }}
                end={{ x: 1, y: 0 }}
                style={styles.generateGradient}
              >
                {isGenerating ? (
                  <ActivityIndicator size="small" color="#ffffff" />
                ) : (
                  <>
                    <Sparkles size={16} color="#ffffff" />
                    <Text style={styles.generateBtnText}>Generate Review & Photos</Text>
                  </>
                )}
              </LinearGradient>
            </TouchableOpacity>
          </View>

          {/* Generated Result Section */}
          {result && (
            <View style={styles.resultSection}>
              {/* Review Card */}
              <View style={styles.reviewCard}>
                <View style={styles.reviewCardHeader}>
                  <View style={styles.starsRow}>
                    {[1, 2, 3, 4, 5].map((s) => (
                      <Star key={s} size={16} color="#f59e0b" fill="#f59e0b" />
                    ))}
                    <Text style={styles.starsText}>5.0 · {result.review?.tone}</Text>
                  </View>

                  <View style={styles.reviewCardActions}>
                    <TouchableOpacity
                      style={styles.copyBtn}
                      onPress={handleCopyReview}
                      activeOpacity={0.7}
                    >
                      {copiedReview ? (
                        <Check size={14} color="#10b981" />
                      ) : (
                        <Copy size={14} color="#4f46e5" />
                      )}
                      <Text style={[styles.copyBtnText, copiedReview && styles.copyBtnTextCopied]}>
                        {copiedReview ? 'Copied!' : 'Copy Review'}
                      </Text>
                    </TouchableOpacity>
                  </View>
                </View>

                {result.review?.headline ? (
                  <Text style={styles.headline}>{result.review.headline}</Text>
                ) : null}

                <Text style={styles.reviewText}>{result.review?.text}</Text>

                {/* Attach to Booking Button */}
                {reviewBookings.length > 0 && (
                  <TouchableOpacity
                    style={styles.attachToBookingBtn}
                    onPress={() => setAttachModalVisible(true)}
                    activeOpacity={0.8}
                  >
                    <CheckCircle2 size={15} color="#059669" />
                    <Text style={styles.attachToBookingBtnText}>
                      Attach to a Review Booking
                    </Text>
                  </TouchableOpacity>
                )}
              </View>

              {/* Photos Gallery */}
              {result.photos && result.photos.length > 0 && (
                <View style={styles.photosSection}>
                  <Text style={styles.photosSectionTitle}>Matching High-Quality Photos</Text>
                  <View style={styles.photosGrid}>
                    {result.photos.map((p, idx) => (
                      <TouchableOpacity
                        key={p.id || idx}
                        style={styles.photoItem}
                        onPress={() => setSelectedPhoto(p)}
                        activeOpacity={0.8}
                      >
                        <Image source={{ uri: p.url || p.thumbUrl }} style={styles.photoThumb} />
                        <View style={styles.photoMeta}>
                          <Text style={styles.photoSource}>{p.source}</Text>
                        </View>
                      </TouchableOpacity>
                    ))}
                  </View>
                </View>
              )}
            </View>
          )}
        </ScrollView>
      )}

      {/* ============================================================== */}
      {/* MODAL 1: ADD / EDIT REVIEW PERSON                              */}
      {/* ============================================================== */}
      <Modal visible={addModalVisible} transparent animationType="fade">
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setAddModalVisible(false)}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Add Review Person</Text>
              <TouchableOpacity onPress={() => setAddModalVisible(false)}>
                <X size={18} color="#64748b" />
              </TouchableOpacity>
            </View>

            <Text style={styles.modalSub}>
              Add names and WhatsApp numbers of people who write reviews for your bookings.
            </Text>

            {/* Name Input */}
            <Text style={styles.fieldLabel}>Full Name *</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="e.g. Sophie Lindner"
              placeholderTextColor="#94a3b8"
              value={newReviewerName}
              onChangeText={setNewReviewerName}
            />

            {/* WhatsApp Phone */}
            <Text style={styles.fieldLabel}>WhatsApp Phone Number</Text>
            <TextInput
              style={styles.modalInput}
              placeholder="e.g. +43 664 1234567"
              placeholderTextColor="#94a3b8"
              keyboardType="phone-pad"
              value={newReviewerPhone}
              onChangeText={setNewReviewerPhone}
            />

            {/* Notes */}
            <Text style={styles.fieldLabel}>Notes (Optional)</Text>
            <TextInput
              style={[styles.modalInput, styles.notesModalInput]}
              placeholder="e.g. English & German speaker, likes morning tours"
              placeholderTextColor="#94a3b8"
              value={newReviewerNotes}
              onChangeText={setNewReviewerNotes}
            />

            {/* Color Tag */}
            <Text style={styles.fieldLabel}>Color Avatar Tag</Text>
            <View style={styles.colorPaletteRow}>
              {COLOR_PALETTE.map((c) => (
                <TouchableOpacity
                  key={c}
                  style={[
                    styles.colorCircle,
                    { backgroundColor: c },
                    newReviewerColor === c && styles.colorCircleSelected,
                  ]}
                  onPress={() => setNewReviewerColor(c)}
                >
                  {newReviewerColor === c && <Check size={14} color="#ffffff" />}
                </TouchableOpacity>
              ))}
            </View>

            {/* Save Button */}
            <TouchableOpacity
              style={styles.saveReviewerBtn}
              onPress={handleSaveReviewer}
              activeOpacity={0.8}
            >
              <Text style={styles.saveReviewerBtnText}>Save Review Person</Text>
            </TouchableOpacity>
          </View>
        </TouchableOpacity>
      </Modal>

      {/* ============================================================== */}
      {/* MODAL 2: ATTACH TO REVIEW BOOKING                              */}
      {/* ============================================================== */}
      <Modal visible={attachModalVisible} transparent animationType="fade">
        <TouchableOpacity
          style={styles.modalOverlay}
          activeOpacity={1}
          onPress={() => setAttachModalVisible(false)}
        >
          <View style={styles.modalContent}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>Attach to Review Booking</Text>
              <TouchableOpacity onPress={() => setAttachModalVisible(false)}>
                <X size={18} color="#64748b" />
              </TouchableOpacity>
            </View>

            <Text style={styles.modalSub}>
              Select which review booking should receive this generated review and photo links:
            </Text>

            <FlatList
              data={reviewBookings}
              keyExtractor={(item) => item.referenceNumber}
              renderItem={({ item }) => {
                const assigned = reviewerAssignments[item.referenceNumber];
                const rev = reviewers.find((r) => r.id === assigned?.reviewerId);

                return (
                  <TouchableOpacity
                    style={styles.bookingPickItem}
                    onPress={() => handleAttachToBooking(item)}
                  >
                    <View style={styles.bookingPickItemLeft}>
                      <Text style={styles.bookingPickRef}>{item.referenceNumber}</Text>
                      <Text style={styles.bookingPickTour} numberOfLines={1}>
                        {item.tourTitle}
                      </Text>
                      <Text style={styles.bookingPickDate}>
                        {item.date} · {rev ? `Reviewer: ${rev.name}` : 'No reviewer assigned'}
                      </Text>
                    </View>
                    <ArrowRight size={16} color="#059669" />
                  </TouchableOpacity>
                );
              }}
            />
          </View>
        </TouchableOpacity>
      </Modal>

      {/* ============================================================== */}
      {/* MODAL 3: FULL PHOTO PREVIEW                                    */}
      {/* ============================================================== */}
      <Modal visible={!!selectedPhoto} transparent animationType="fade">
        <View style={styles.photoModalOverlay}>
          <TouchableOpacity
            style={styles.photoModalClose}
            onPress={() => setSelectedPhoto(null)}
          >
            <X size={22} color="#ffffff" />
          </TouchableOpacity>
          {selectedPhoto && (
            <Image
              source={{ uri: selectedPhoto.url || selectedPhoto.thumbUrl }}
              style={styles.fullPhoto}
              resizeMode="contain"
            />
          )}
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  subTabBar: {
    flexDirection: 'row',
    backgroundColor: '#ffffff',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#e2e8f0',
    gap: 10,
  },
  subTabButton: {
    flex: 1,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    paddingVertical: 10,
    borderRadius: 12,
    backgroundColor: '#f1f5f9',
  },
  subTabButtonActive: {
    backgroundColor: '#ecfdf5',
    borderWidth: 1,
    borderColor: '#a7f3d0',
  },
  subTabButtonActiveStudio: {
    backgroundColor: '#eef2ff',
    borderWidth: 1,
    borderColor: '#c7d2fe',
  },
  subTabButtonText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#64748b',
  },
  subTabButtonTextActive: {
    color: '#065f46',
  },
  subTabButtonTextActiveStudio: {
    color: '#4338ca',
  },
  tabContent: {
    flex: 1,
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 40,
  },
  peopleHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 16,
  },
  peopleTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: '#0f172a',
  },
  peopleSubtitle: {
    fontSize: 11,
    color: '#64748b',
    marginTop: 2,
    maxWidth: 220,
  },
  addReviewerBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#059669',
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 10,
  },
  addReviewerBtnText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#ffffff',
  },
  emptyStateBox: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 30,
    marginTop: 20,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  emptyStateTitle: {
    fontSize: 15,
    fontWeight: '800',
    color: '#334155',
    marginTop: 12,
  },
  emptyStateSubtitle: {
    fontSize: 12,
    color: '#64748b',
    textAlign: 'center',
    marginTop: 6,
    lineHeight: 18,
  },
  reviewersList: {
    gap: 12,
  },
  reviewerCard: {
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 14,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 6,
  },
  reviewerCardTop: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 10,
  },
  reviewerCardInfo: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    flex: 1,
  },
  reviewerAvatar: {
    width: 38,
    height: 38,
    borderRadius: 19,
    alignItems: 'center',
    justifyContent: 'center',
  },
  reviewerAvatarInitial: {
    color: '#ffffff',
    fontWeight: '800',
    fontSize: 16,
  },
  reviewerName: {
    fontSize: 14,
    fontWeight: '800',
    color: '#0f172a',
  },
  reviewerNotes: {
    fontSize: 11,
    color: '#64748b',
    marginTop: 1,
  },
  deleteRevBtn: {
    padding: 6,
  },
  reviewerContactRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#f8fafc',
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: 10,
    marginBottom: 8,
  },
  reviewerPhoneBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
  },
  reviewerPhoneText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#334155',
  },
  quickChatBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#ecfdf5',
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#a7f3d0',
  },
  quickChatBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#059669',
  },
  reviewerAssignmentsRow: {
    borderTopWidth: 1,
    borderTopColor: '#f1f5f9',
    paddingTop: 8,
  },
  assignmentCountLabel: {
    fontSize: 10,
    color: '#64748b',
    fontWeight: '600',
    marginBottom: 4,
  },
  assignedPillsList: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  bookingRefPill: {
    backgroundColor: '#f1f5f9',
    paddingHorizontal: 8,
    paddingVertical: 3,
    borderRadius: 6,
  },
  bookingRefPillText: {
    fontSize: 10,
    fontWeight: '800',
    color: '#334155',
    fontFamily: 'Courier',
  },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    marginBottom: 16,
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
    fontSize: 18,
    fontWeight: '800',
    color: '#0f172a',
  },
  subtitle: {
    fontSize: 12,
    color: '#64748b',
    marginTop: 2,
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#0f172a',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.04,
    shadowRadius: 6,
  },
  inputLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#334155',
    marginBottom: 6,
  },
  inputRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: '#f8fafc',
    borderRadius: 12,
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  textInput: {
    flex: 1,
    fontSize: 13,
    color: '#0f172a',
    padding: 0,
  },
  tonesScroll: {
    flexDirection: 'row',
    gap: 8,
  },
  tonePill: {
    paddingHorizontal: 12,
    paddingVertical: 8,
    borderRadius: 14,
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#e2e8f0',
    marginRight: 8,
  },
  tonePillActive: {
    backgroundColor: '#eef2ff',
    borderColor: '#4f46e5',
  },
  toneLabel: {
    fontSize: 12,
    fontWeight: '700',
    color: '#334155',
  },
  toneLabelActive: {
    color: '#4f46e5',
  },
  toneDesc: {
    fontSize: 10,
    color: '#94a3b8',
    marginTop: 2,
  },
  toneDescActive: {
    color: '#6366f1',
  },
  notesInput: {
    backgroundColor: '#f8fafc',
    borderRadius: 12,
    padding: 12,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    fontSize: 13,
    color: '#0f172a',
    textAlignVertical: 'top',
    minHeight: 70,
  },
  generateBtnWrapper: {
    marginTop: 16,
    borderRadius: 14,
    overflow: 'hidden',
  },
  generateGradient: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    paddingVertical: 14,
  },
  generateBtnText: {
    fontSize: 14,
    fontWeight: '800',
    color: '#ffffff',
  },
  resultSection: {
    marginTop: 20,
    gap: 16,
  },
  reviewCard: {
    backgroundColor: '#ffffff',
    borderRadius: 20,
    padding: 18,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  reviewCardHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 12,
  },
  reviewCardActions: {
    flexDirection: 'row',
    gap: 6,
  },
  starsRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 3,
  },
  starsText: {
    fontSize: 12,
    fontWeight: '700',
    color: '#64748b',
    marginLeft: 6,
  },
  copyBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    backgroundColor: '#eef2ff',
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: 10,
  },
  copyBtnText: {
    fontSize: 11,
    fontWeight: '700',
    color: '#4f46e5',
  },
  copyBtnTextCopied: {
    color: '#10b981',
  },
  headline: {
    fontSize: 15,
    fontWeight: '800',
    color: '#0f172a',
    marginBottom: 8,
  },
  reviewText: {
    fontSize: 13,
    color: '#334155',
    lineHeight: 20,
    fontWeight: '500',
  },
  attachToBookingBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 6,
    backgroundColor: '#ecfdf5',
    paddingVertical: 10,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: '#a7f3d0',
    marginTop: 14,
  },
  attachToBookingBtnText: {
    fontSize: 12,
    fontWeight: '800',
    color: '#065f46',
  },
  photosSection: {
    gap: 10,
  },
  photosSectionTitle: {
    fontSize: 14,
    fontWeight: '800',
    color: '#0f172a',
  },
  photosGrid: {
    flexDirection: 'row',
    gap: 10,
  },
  photoItem: {
    flex: 1,
    height: 120,
    borderRadius: 14,
    overflow: 'hidden',
    backgroundColor: '#e2e8f0',
  },
  photoThumb: {
    width: '100%',
    height: '100%',
  },
  photoMeta: {
    position: 'absolute',
    bottom: 6,
    left: 6,
    backgroundColor: 'rgba(0,0,0,0.6)',
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
  },
  photoSource: {
    fontSize: 9,
    color: '#ffffff',
    fontWeight: '700',
  },
  photoModalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.92)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  photoModalClose: {
    position: 'absolute',
    top: 50,
    right: 20,
    zIndex: 10,
    padding: 8,
  },
  fullPhoto: {
    width: '94%',
    height: '75%',
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
  notesModalInput: {
    minHeight: 50,
  },
  colorPaletteRow: {
    flexDirection: 'row',
    gap: 10,
    marginBottom: 16,
  },
  colorCircle: {
    width: 32,
    height: 32,
    borderRadius: 16,
    alignItems: 'center',
    justifyContent: 'center',
  },
  colorCircleSelected: {
    borderWidth: 2,
    borderColor: '#0f172a',
  },
  saveReviewerBtn: {
    backgroundColor: '#059669',
    paddingVertical: 12,
    borderRadius: 12,
    alignItems: 'center',
    shadowColor: '#059669',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.25,
    shadowRadius: 4,
  },
  saveReviewerBtnText: {
    fontSize: 13,
    fontWeight: '800',
    color: '#ffffff',
  },
  bookingPickItem: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: 10,
    paddingHorizontal: 8,
    borderBottomWidth: 1,
    borderBottomColor: '#f1f5f9',
  },
  bookingPickItemLeft: {
    flex: 1,
    paddingRight: 10,
  },
  bookingPickRef: {
    fontSize: 11,
    fontWeight: '800',
    color: '#1e293b',
    fontFamily: 'Courier',
  },
  bookingPickTour: {
    fontSize: 12,
    color: '#334155',
    fontWeight: '600',
    marginTop: 2,
  },
  bookingPickDate: {
    fontSize: 10,
    color: '#64748b',
    marginTop: 2,
  },
});

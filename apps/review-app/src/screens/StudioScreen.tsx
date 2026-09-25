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
} from 'lucide-react-native';
import { ReviewTone, AnalyzeResponse, PhotoItem } from '../types';
import { analyzeTourRequest } from '../api/client';

interface StudioScreenProps {
  prefilledUrl?: string;
  prefilledNotes?: string;
  onClearPrefill?: () => void;
  onSaveToHistory?: (result: AnalyzeResponse) => void;
}

export function StudioScreen({
  prefilledUrl = '',
  prefilledNotes = '',
  onClearPrefill,
  onSaveToHistory,
}: StudioScreenProps) {
  const [url, setUrl] = useState(prefilledUrl);
  const [notes, setNotes] = useState(prefilledNotes);
  const [selectedTone, setSelectedTone] = useState<ReviewTone>('balanced');
  const [isGenerating, setIsGenerating] = useState(false);
  const [result, setResult] = useState<AnalyzeResponse | null>(null);
  const [copiedReview, setCopiedReview] = useState(false);
  const [selectedPhoto, setSelectedPhoto] = useState<PhotoItem | null>(null);

  const tones: { key: ReviewTone; label: string; desc: string }[] = [
    { key: 'balanced', label: 'Balanced', desc: 'Authentic & helpful' },
    { key: 'enthusiastic', label: 'Enthusiastic', desc: '5-star excited' },
    { key: 'detailed', label: 'Detailed', desc: 'In-depth itinerary' },
    { key: 'casual', label: 'Casual', desc: 'Friendly traveler' },
    { key: 'punchy', label: 'Punchy', desc: 'Short & memorable' },
  ];

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

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.content}>
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

            {result.review?.headline ? (
              <Text style={styles.headline}>{result.review.headline}</Text>
            ) : null}

            <Text style={styles.reviewText}>{result.review?.text}</Text>
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

      {/* Photo Modal */}
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
});

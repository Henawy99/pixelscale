import { useEffect, useMemo, useRef, useState } from 'react';
import { Alert, Pressable, ScrollView, Share } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Image as ExpoImage } from 'expo-image';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import {
  Button,
  Form,
  HStack,
  Image,
  Menu,
  Picker,
  ProgressView,
  RNHostView,
  Section,
  Spacer,
  Text,
  TextField,
  VStack,
} from '@expo/ui/swift-ui';
import {
  autocorrectionDisabled,
  buttonStyle,
  controlSize,
  disabled,
  frame,
  keyboardType,
  lineLimit,
  scrollDismissesKeyboard,
  tag,
  textInputAutocapitalization,
  textSelection,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { AnalyzeResponse, BookingItem, ReviewTone, isBookingReview } from '@/types';
import { analyzeTourRequest } from '@/api/client';
import { ACCENT, text } from '@/components/theme';
import { useField } from '@/components/use-field';
import { reviewNotesFor } from '@/lib/tours';
import { bookingDate } from '@/lib/dates';

const TONES: { key: ReviewTone; label: string; desc: string }[] = [
  { key: 'balanced', label: 'Balanced', desc: 'Authentic & helpful' },
  { key: 'enthusiastic', label: 'Enthusiastic', desc: '5-star excited' },
  { key: 'detailed', label: 'Detailed', desc: 'In-depth itinerary' },
  { key: 'casual', label: 'Casual', desc: 'Friendly traveler' },
  { key: 'punchy', label: 'Punchy', desc: 'Short & memorable' },
];

export default function StudioScreen() {
  const params = useLocalSearchParams<{ url?: string; notes?: string; bookingRef?: string; autostart?: string }>();
  const router = useRouter();
  const { offeredTours, bookings, reviewers, reviewerAssignments, assignReviewer, addHistory } = useAppData();

  const url = useField(params.url ?? '');
  const notes = useField(params.notes ?? '');
  const [reviewTone, setReviewTone] = useState<ReviewTone>('balanced');
  const [isGenerating, setIsGenerating] = useState(false);
  const [result, setResult] = useState<AnalyzeResponse | null>(null);
  const [copied, setCopied] = useState(false);
  const [attachedRef, setAttachedRef] = useState<string | null>(null);

  const selectedTourId = offeredTours.find((t) => t.gygUrl === url.value.trim())?.id ?? 'custom';
  // Soonest first, so the booking that needs a review next is at the top of the menu.
  const reviewBookings = useMemo(
    () =>
      bookings
        .filter((b) => b.status !== 'cancelled' && isBookingReview(b))
        .sort((a, b) => (a.timestamp ?? 0) - (b.timestamp ?? 0)),
    [bookings]
  );
  const targetBooking = params.bookingRef
    ? reviewBookings.find((b) => b.referenceNumber === params.bookingRef)
    : undefined;

  const pickTour = (id: string) => {
    const tour = offeredTours.find((t) => t.id === id);
    if (!tour) return;
    Haptics.selectionAsync();
    url.set(tour.gygUrl);
    const current = notes.current().trim();
    if (!current || current.startsWith('Tour: ')) notes.set(reviewNotesFor(tour));
  };

  const generate = async () => {
    if (!url.current().trim()) {
      Alert.alert('Tour Required', 'Enter a GetYourGuide link or a tour name.');
      return;
    }
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setIsGenerating(true);
    setResult(null);
    setAttachedRef(null);
    try {
      const res = await analyzeTourRequest({
        url: url.current().trim(),
        tone: reviewTone,
        customNotes: notes.current().trim() || undefined,
      });
      if (!res.success || res.error) {
        Alert.alert('Couldn’t Generate', res.error || 'Check your Gemini API key in Settings.');
      } else {
        Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
        setResult(res);
        await addHistory(res);
      }
    } catch (err) {
      Alert.alert('Network Error', err instanceof Error ? err.message : 'Request failed');
    } finally {
      setIsGenerating(false);
    }
  };

  // Opened from a booking whose tour is known: the link is already filled in, so start writing straight away.
  const autostarted = useRef(false);
  useEffect(() => {
    if (params.autostart !== '1' || autostarted.current || !url.current().trim()) return;
    autostarted.current = true;
    generate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const copyReview = async () => {
    if (!result?.review?.text) return;
    await Clipboard.setStringAsync(result.review.text);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const attachTo = async (booking: BookingItem) => {
    if (!result?.review?.text) return;
    const reviewerId = reviewerAssignments[booking.referenceNumber]?.reviewerId || reviewers[0]?.id || '';
    const photoUrls = (result.photos || []).map((p) => p.url).filter(Boolean);
    await assignReviewer(booking.referenceNumber, reviewerId, result.review.text, photoUrls, result.review.headline);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setAttachedRef(booking.referenceNumber);
  };

  const review = result?.review;
  const photos = result?.photos ?? [];

  return (
    <>
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button icon="xmark" onPress={() => router.back()} accessibilityLabel="Close" />
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <Form modifiers={[scrollDismissesKeyboard('interactively')]}>
          <Section
            title="Tour"
            footer={<Text>Pick one of your tours or paste any GetYourGuide link or tour name.</Text>}>
            {offeredTours.length > 0 ? (
              <Picker
                label="Your tours"
                systemImage="map"
                selection={selectedTourId}
                onSelectionChange={(v) => pickTour(String(v))}>
                <Text modifiers={[tag('custom')]}>Custom</Text>
                {offeredTours.map((t) => (
                  <Text key={t.id} modifiers={[tag(t.id)]}>
                    {t.title}
                  </Text>
                ))}
              </Picker>
            ) : null}
            <TextField
              text={url.state}
              onTextChange={url.onTextChange}
              placeholder="getyourguide.com/… or tour name"
              axis="vertical"
              modifiers={[
                lineLimit({ min: 1, max: 3 }),
                keyboardType('url'),
                textInputAutocapitalization('never'),
                autocorrectionDisabled(),
              ]}
            />
          </Section>

          <Section title="Style">
            <Picker
              label="Tone"
              systemImage="text.bubble"
              selection={reviewTone}
              onSelectionChange={(v) => setReviewTone(v as ReviewTone)}>
              {TONES.map((t) => (
                <Text key={t.key} modifiers={[tag(t.key)]}>
                  {`${t.label} — ${t.desc}`}
                </Text>
              ))}
            </Picker>
          </Section>

          <Section title="Notes" footer={<Text>Optional: guide names, weather, highlights to mention.</Text>}>
            <TextField
              text={notes.state}
              onTextChange={notes.onTextChange}
              placeholder="e.g. Friendly driver Thomas, sunny day in Hallstatt"
              axis="vertical"
              modifiers={[lineLimit({ min: 2, max: 6 })]}
            />
          </Section>

          <Section>
            <Button
              onPress={generate}
              modifiers={[buttonStyle('borderedProminent'), controlSize('large'), disabled(isGenerating)]}>
              <HStack spacing={8} modifiers={[frame({ maxWidth: Infinity })]}>
                <Spacer />
                {isGenerating ? <ProgressView /> : <Image systemName="sparkles" size={16} color="white" />}
                <Text modifiers={[text.headline]}>{isGenerating ? 'Writing…' : result ? 'Generate Again' : 'Generate Review & Photos'}</Text>
                <Spacer />
              </HStack>
            </Button>
          </Section>

          {review ? (
            <>
              <Section title="Review">
                <VStack alignment="leading" spacing={8}>
                  <HStack spacing={2}>
                    {[0, 1, 2, 3, 4].map((i) => (
                      <Image key={i} systemName="star.fill" size={14} color="#F5A524" />
                    ))}
                    <Text modifiers={[text.footnote, text.secondary]}>{`  ${TONES.find((t) => t.key === review.tone)?.label ?? review.tone}`}</Text>
                  </HStack>
                  {review.headline ? <Text modifiers={[text.headline]}>{review.headline}</Text> : null}
                  <Text modifiers={[text.body, textSelection(true)]}>{review.text}</Text>
                </VStack>
              </Section>

              <Section
                footer={
                  attachedRef ? (
                    <Text>{`Attached to ${attachedRef} with ${photos.length} photo links.`}</Text>
                  ) : undefined
                }>
                {targetBooking ? (
                  <Button
                    label={attachedRef === targetBooking.referenceNumber ? `Attached to ${targetBooking.referenceNumber}` : `Attach to ${targetBooking.referenceNumber}`}
                    systemImage={attachedRef === targetBooking.referenceNumber ? 'checkmark.circle.fill' : 'paperclip'}
                    onPress={() => attachTo(targetBooking)}
                  />
                ) : null}
                {reviewBookings.length > 0 ? (
                  <Menu label={targetBooking ? 'Attach to Another Booking' : 'Attach to Review Booking'} systemImage="paperclip">
                    {reviewBookings.map((b) => {
                      const hasReview = !!reviewerAssignments[b.referenceNumber]?.reviewText;
                      const when = bookingDate(b)?.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
                      return (
                        <Button
                          key={b.referenceNumber}
                          label={[when, b.customerName || 'Customer', b.referenceNumber].filter(Boolean).join(' · ')}
                          systemImage={hasReview ? 'checkmark.circle' : undefined}
                          onPress={() => attachTo(b)}
                        />
                      );
                    })}
                  </Menu>
                ) : null}
                <Button label={copied ? 'Copied' : 'Copy Review'} systemImage={copied ? 'checkmark' : 'doc.on.doc'} onPress={copyReview} />
                <Button
                  label="Share"
                  systemImage="square.and.arrow.up"
                  onPress={() => Share.share({ message: review.headline ? `${review.headline}\n\n${review.text}` : review.text })}
                />
              </Section>

              {photos.length > 0 ? (
                <Section title={`Photos · ${photos.length}`} footer={<Text>Tap a photo to view it full size.</Text>}>
                  <RNHostView matchContents>
                    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingHorizontal: 16 }} style={{ height: 120, marginHorizontal: -16 }}>
                      {photos.map((p, i) => (
                        <Pressable
                          key={p.id || i}
                          onPress={() => router.push({ pathname: '/photo', params: { uri: p.url || p.thumbUrl, credit: `${p.source} · ${p.photographer}` } })}>
                          <ExpoImage
                            source={{ uri: p.thumbUrl || p.url }}
                            style={{ width: 160, height: 120, borderRadius: 10 }}
                            contentFit="cover"
                            transition={200}
                          />
                        </Pressable>
                      ))}
                    </ScrollView>
                  </RNHostView>
                </Section>
              ) : null}
            </>
          ) : null}
        </Form>
      </Host>
    </>
  );
}

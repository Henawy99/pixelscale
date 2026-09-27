import { useState } from 'react';
import { Alert, Pressable, ScrollView, Text as RNText, View } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import { Image as ExpoImage } from 'expo-image';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import * as ImagePicker from 'expo-image-picker';
import { Host } from '@expo/ui';
import { Button, Form, HStack, Image, Label, RNHostView, Section, Spacer, Text, TextField, VStack } from '@expo/ui/swift-ui';
import {
  buttonStyle,
  controlSize,
  disabled,
  foregroundStyle,
  frame,
  lineLimit,
  scrollDismissesKeyboard,
  tint,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { BookingItem, getNumericPrice } from '@/types';
import { getBookingTicketDeduction } from '@/lib/tours';
import { formatEur, platformFeeRate, platformName } from '@/lib/finance';
import { addCustomerPhotos, listCustomerPhotos, removeCustomerPhoto } from '@/lib/customerPhotos';
import { canShareSeveralFiles, shareFiles } from '@/lib/shareSheet';
import { shareToWhatsApp } from '@/lib/reviewerStorage';
import { firstName, photoThankYouMessage } from '@/lib/guestMessages';
import { openUrl } from '@/lib/links';
import { Tag, ValueRow } from '@/components/primitives';
import { ACCENT, text, tone } from '@/components/theme';
import { useField } from '@/components/use-field';

const THUMB = 96;

/**
 * Review bookings only need three things: what they pay out, the photos taken of the guests, and a
 * way to send those photos to the guest on WhatsApp. "Done" marks the booking green in the lists.
 */
export function ReviewBookingDetail({ booking }: { booking: BookingItem }) {
  const router = useRouter();
  const { matchTour, doneBookings, setBookingDone } = useAppData();
  const ref = booking.referenceNumber;
  const doneAt = doneBookings[ref];
  const name = firstName(booking);
  const phone = booking.customerPhone?.trim();

  const [photos, setPhotos] = useState(() => listCustomerPhotos(ref));
  const [adding, setAdding] = useState(false);
  const message = useField(photoThankYouMessage(booking));

  const gross = getNumericPrice(booking);
  const net = getBookingTicketDeduction(booking, matchTour).netGygPayout;

  const addPhotos = async () => {
    const picked = await ImagePicker.launchImageLibraryAsync({
      mediaTypes: ['images'],
      allowsMultipleSelection: true,
      orderedSelection: true,
      quality: 0.8,
    });
    if (picked.canceled || picked.assets.length === 0) return;
    setAdding(true);
    try {
      setPhotos(await addCustomerPhotos(ref, picked.assets.map((a) => a.uri)));
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    } catch (err) {
      Alert.alert('Couldn’t Add Photos', err instanceof Error ? err.message : 'Please try again.');
    } finally {
      setAdding(false);
    }
  };

  const removePhoto = (uri: string) =>
    Alert.alert('Remove Photo?', 'It stays in your gallery.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Remove',
        style: 'destructive',
        onPress: () => {
          Haptics.selectionAsync();
          setPhotos(removeCustomerPhoto(ref, uri));
        },
      },
    ]);

  // Photos go through the share sheet (WhatsApp can't be pre-filled with attachments), so the message
  // is also copied in case WhatsApp only takes the photos. Without photos, the guest's chat opens directly.
  const sendOnWhatsApp = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    const body = message.current().trim();
    try {
      if (photos.length === 0) {
        await shareToWhatsApp(phone, body);
        return;
      }
      if (body) await Clipboard.setStringAsync(body);
      await shareFiles(photos, body);
    } catch (err) {
      Alert.alert('Couldn’t Share', err instanceof Error ? err.message : 'Please try again.');
    }
  };

  const toggleDone = async () => {
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    await setBookingDone(ref, !doneAt);
  };

  const sendFooter =
    photos.length === 0
      ? `Opens ${name ? `${name}’s` : 'the guest’s'} WhatsApp chat with the message. Add photos above to send them too.`
      : !canShareSeveralFiles && photos.length > 1
        ? 'This build can only share the first photo. Install the latest TestFlight build to send them all at once.'
        : `Choose WhatsApp, then ${name ? `${name}’s` : 'the guest’s'} chat. The message is also copied, so you can paste it if WhatsApp only takes the photos.`;

  return (
    <>
      <Stack.Screen options={{ title: ref }} />
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button icon="xmark" onPress={() => router.back()} accessibilityLabel="Close" />
      </Stack.Toolbar>
      {booking.bookingUrl ? (
        <Stack.Toolbar placement="right">
          <Stack.Toolbar.Button
            icon="safari"
            onPress={() => openUrl(booking.bookingUrl!)}
            accessibilityLabel={`Open in ${platformName(booking)}`}
          />
        </Stack.Toolbar>
      ) : null}

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <Form modifiers={[scrollDismissesKeyboard('interactively')]}>
          <Section>
            <HStack spacing={12}>
              <VStack alignment="leading" spacing={4}>
                <Text modifiers={[text.headline]}>{booking.customerName || 'Guest'}</Text>
                <Text modifiers={[text.footnote, text.secondary, text.twoLines]}>{booking.tourTitle}</Text>
              </VStack>
              <Spacer />
              {doneAt ? <Tag label="Done" color={tone.positive} icon="checkmark" /> : null}
            </HStack>
          </Section>

          <Section title="Payout">
            <ValueRow title="Gross price" value={formatEur(gross)} />
            <ValueRow
              title={`${platformName(booking)} fee (${Math.round(platformFeeRate(booking) * 100)}%)`}
              value={`− ${formatEur(gross - net)}`}
            />
            <ValueRow title="Net payout" value={formatEur(net)} valueColor={tone.positive} bold />
          </Section>

          <Section
            title={photos.length ? `Photos · ${photos.length}` : 'Photos'}
            footer={
              <Text>
                {photos.length ? 'Tap a photo to view it, long-press to remove it.' : 'Add the photos you took of the guests.'}
              </Text>
            }>
            {photos.length ? (
              // The host takes the row's width; with matchContents the strip sized itself to the screen
              // and SwiftUI centred it, clipping the first photo.
              <HStack modifiers={[frame({ height: THUMB })]}>
                <RNHostView>
                  <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 8 }}>
                    {photos.map((uri, i) => (
                      <Pressable
                        key={uri}
                        onPress={() => router.push({ pathname: '/photo', params: { uri } })}
                        onLongPress={() => removePhoto(uri)}
                        accessibilityLabel={`Photo ${i + 1}`}>
                        <ExpoImage source={{ uri }} style={{ width: THUMB, height: THUMB, borderRadius: 10 }} contentFit="cover" />
                        <View
                          style={{
                            position: 'absolute',
                            left: 6,
                            bottom: 6,
                            minWidth: 20,
                            paddingHorizontal: 5,
                            borderRadius: 10,
                            backgroundColor: '#00000080',
                          }}>
                          <RNText style={{ color: 'white', fontSize: 11, fontWeight: '600', textAlign: 'center' }}>{i + 1}</RNText>
                        </View>
                      </Pressable>
                    ))}
                  </ScrollView>
                </RNHostView>
              </HStack>
            ) : null}
            <Button onPress={addPhotos} modifiers={[disabled(adding)]}>
              <Label
                title={adding ? 'Adding…' : photos.length ? 'Add More Photos' : 'Add Photos from Gallery'}
                systemImage="photo.badge.plus"
              />
            </Button>
          </Section>

          <Section title="Message">
            <TextField
              text={message.state}
              onTextChange={message.onTextChange}
              placeholder="Message to the guest"
              axis="vertical"
              modifiers={[lineLimit({ min: 3, max: 8 })]}
            />
          </Section>

          <Section footer={<Text>{sendFooter}</Text>}>
            <Button onPress={sendOnWhatsApp} modifiers={[tint('green'), buttonStyle('borderedProminent'), controlSize('large')]}>
              <HStack spacing={8} modifiers={[frame({ maxWidth: Infinity })]}>
                <Spacer />
                <Image systemName="paperplane.fill" size={16} color="white" />
                <Text modifiers={[text.headline]}>
                  {photos.length ? `Send ${photos.length} ${photos.length === 1 ? 'Photo' : 'Photos'} on WhatsApp` : 'Send on WhatsApp'}
                </Text>
                <Spacer />
              </HStack>
            </Button>
            {photos.length > 0 && phone ? (
              <Button onPress={() => shareToWhatsApp(phone, message.current().trim())}>
                <Label title={`Open Chat with ${name || 'Guest'}`} systemImage="bubble.left.and.bubble.right" />
              </Button>
            ) : null}
          </Section>

          <Section
            footer={
              <Text>
                {doneAt
                  ? `Marked done ${new Date(doneAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}.`
                  : 'Turns this booking green in your lists.'}
              </Text>
            }>
            {doneAt ? (
              <Button onPress={toggleDone}>
                <Label title="Mark as Not Done" systemImage="arrow.uturn.backward" />
              </Button>
            ) : (
              <Button onPress={toggleDone}>
                <Label title="Mark as Done" systemImage="checkmark.circle.fill" modifiers={[foregroundStyle(tone.positive)]} />
              </Button>
            )}
          </Section>
        </Form>
      </Host>
    </>
  );
}

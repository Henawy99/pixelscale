import { useState } from 'react';
import { Alert } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, Form, Section, Text, TextField } from '@expo/ui/swift-ui';
import {
  foregroundStyle,
  keyboardType,
  lineLimit,
  scrollDismissesKeyboard,
  textContentType,
  textInputAutocapitalization,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { shareToWhatsApp } from '@/lib/reviewerStorage';
import { ColorSwatches } from '@/components/primitives';
import { ACCENT, DRIVER_COLORS } from '@/components/theme';
import { useField } from '@/components/use-field';

export default function ReviewerFormScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const router = useRouter();
  const { reviewers, reviewerAssignments, saveReviewer, deleteReviewer } = useAppData();
  const existing = reviewers.find((r) => r.id === id);

  const name = useField(existing?.name ?? '');
  const phone = useField(existing?.whatsappPhone || existing?.phone || '');
  const notes = useField(existing?.notes ?? '');
  const [color, setColor] = useState(
    existing?.color ?? DRIVER_COLORS[reviewers.length % DRIVER_COLORS.length]
  );

  const attachedRefs = existing
    ? Object.values(reviewerAssignments)
        .filter((a) => a.reviewerId === existing.id)
        .map((a) => a.bookingRef)
    : [];

  const save = async () => {
    if (!name.current().trim()) {
      Alert.alert('Name Required', 'Enter the person’s name.');
      return;
    }
    await saveReviewer({
      id: existing?.id ?? `rev_${Date.now()}`,
      name: name.current().trim(),
      phone: phone.current().trim(),
      whatsappPhone: phone.current().trim(),
      color,
      notes: notes.current().trim() || undefined,
      createdAt: existing?.createdAt ?? Date.now(),
    });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.back();
  };

  const remove = () => {
    if (!existing) return;
    Alert.alert(`Delete ${existing.name}?`, 'They are also detached from any review bookings.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await deleteReviewer(existing.id);
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
          router.back();
        },
      },
    ]);
  };

  return (
    <>
      <Stack.Screen options={{ title: existing ? existing.name : 'New Review Person' }} />
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button onPress={() => router.back()}>Cancel</Stack.Toolbar.Button>
      </Stack.Toolbar>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button variant="done" tintColor={ACCENT} disabled={!name.value.trim()} onPress={save}>
          Save
        </Stack.Toolbar.Button>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <Form modifiers={[scrollDismissesKeyboard('interactively')]}>
          <Section footer={<Text>The WhatsApp number receives the review text and photo links.</Text>}>
            <TextField
              text={name.state}
              onTextChange={name.onTextChange}
              placeholder="Full name"
              autoFocus={!existing}
              modifiers={[textContentType('name'), textInputAutocapitalization('words')]}
            />
            <TextField
              text={phone.state}
              onTextChange={phone.onTextChange}
              placeholder="WhatsApp, e.g. +43 664 1234567"
              modifiers={[keyboardType('phone-pad'), textContentType('telephoneNumber')]}
            />
          </Section>

          <Section title="Color">
            <ColorSwatches colors={DRIVER_COLORS} value={color} onChange={setColor} />
          </Section>

          <Section title="Notes">
            <TextField
              text={notes.state}
              onTextChange={notes.onTextChange}
              placeholder="Languages, availability…"
              axis="vertical"
              modifiers={[lineLimit({ min: 2, max: 5 })]}
            />
          </Section>

          {existing ? (
            <>
              <Section title={`Attached Bookings · ${attachedRefs.length}`}>
                {attachedRefs.length === 0 ? (
                  <Text>None yet</Text>
                ) : (
                  attachedRefs.map((ref) => (
                    <Button
                      key={ref}
                      label={ref}
                      systemImage="ticket"
                      onPress={() => router.push(`/booking/${encodeURIComponent(ref)}`)}
                    />
                  ))
                )}
              </Section>
              <Section>
                {phone.value.trim() ? (
                  <Button
                    label="Chat on WhatsApp"
                    systemImage="message.fill"
                    onPress={() => shareToWhatsApp(phone.current().trim(), `Hi ${existing.name}! We have some new tour reviews to organize.`)}
                  />
                ) : null}
                <Button role="destructive" label="Delete Review Person" systemImage="trash" onPress={remove} modifiers={[foregroundStyle('red')]} />
              </Section>
            </>
          ) : null}
        </Form>
      </Host>
    </>
  );
}

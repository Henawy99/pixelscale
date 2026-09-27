import { useState } from 'react';
import { Alert } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, Form, HStack, Picker, Section, Text, TextField } from '@expo/ui/swift-ui';
import {
  foregroundStyle,
  keyboardType,
  lineLimit,
  pickerStyle,
  scrollDismissesKeyboard,
  tag,
  textContentType,
  textInputAutocapitalization,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { Driver } from '@/types';
import { ColorSwatches } from '@/components/primitives';
import { ACCENT, DRIVER_COLORS } from '@/components/theme';
import { parseAmount, useField } from '@/components/use-field';

export default function DriverFormScreen() {
  const { id } = useLocalSearchParams<{ id?: string }>();
  const router = useRouter();
  const { drivers, saveDriver, deleteDriver } = useAppData();
  const existing = drivers.find((d) => d.id === id);

  const name = useField(existing?.name ?? '');
  const phone = useField(existing?.phone ?? '');
  const rate = useField(existing ? String(existing.defaultPayoutRate) : '50');
  const notes = useField(existing?.notes ?? '');
  const [payoutType, setPayoutType] = useState<Driver['payoutType']>(existing?.payoutType ?? 'percentage');
  const [color, setColor] = useState(
    existing?.color ?? DRIVER_COLORS[drivers.length % DRIVER_COLORS.length]
  );

  const changeType = (next: Driver['payoutType']) => {
    setPayoutType(next);
    // Swap the untouched default so the number makes sense for the new unit.
    if (next === 'fixed' && rate.current() === '50') rate.set('150');
    if (next === 'percentage' && (rate.current() === '150' || rate.current() === '120')) rate.set('50');
  };

  const save = async () => {
    if (!name.current().trim()) {
      Alert.alert('Name Required', 'Enter the driver’s name.');
      return;
    }
    const rateNum = parseAmount(rate.current());
    if (isNaN(rateNum) || rateNum < 0) {
      Alert.alert('Invalid Rate', 'Enter a valid percentage or euro amount.');
      return;
    }
    await saveDriver({
      id: existing?.id ?? `drv_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`,
      name: name.current().trim(),
      phone: phone.current().trim(),
      payoutType,
      defaultPayoutRate: rateNum,
      color,
      notes: notes.current().trim() || undefined,
      createdAt: existing?.createdAt ?? Date.now(),
    });
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.back();
  };

  const remove = () => {
    if (!existing) return;
    Alert.alert(`Delete ${existing.name}?`, 'Their tours become unassigned and their earnings are removed.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await deleteDriver(existing.id);
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
          router.dismissTo('/team');
        },
      },
    ]);
  };

  return (
    <>
      <Stack.Screen options={{ title: existing ? 'Edit Driver' : 'New Driver' }} />
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
          <Section>
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
              placeholder="Phone, e.g. +43 664 1234567"
              modifiers={[keyboardType('phone-pad'), textContentType('telephoneNumber')]}
            />
          </Section>

          <Section
            title="Payout"
            footer={
              <Text>
                {payoutType === 'percentage'
                  ? 'Share of the net payout after the platform fee (30% GetYourGuide, 20% Airbnb).'
                  : 'The same euro amount for every tour.'}
              </Text>
            }>
            <Picker
              selection={payoutType}
              onSelectionChange={(v) => changeType(v as Driver['payoutType'])}
              modifiers={[pickerStyle('segmented')]}>
              <Text modifiers={[tag('percentage')]}>% of net</Text>
              <Text modifiers={[tag('fixed')]}>Fixed per tour</Text>
            </Picker>
            <HStack spacing={8}>
              <Text>{payoutType === 'percentage' ? 'Percentage' : 'Amount €'}</Text>
              <TextField
                text={rate.state}
                onTextChange={rate.onTextChange}
                placeholder={payoutType === 'percentage' ? '50' : '150'}
                modifiers={[keyboardType('decimal-pad')]}
              />
            </HStack>
          </Section>

          <Section title="Color">
            <ColorSwatches colors={DRIVER_COLORS} value={color} onChange={setColor} />
          </Section>

          <Section title="Notes">
            <TextField
              text={notes.state}
              onTextChange={notes.onTextChange}
              placeholder="Vehicle, languages, regions…"
              axis="vertical"
              modifiers={[lineLimit({ min: 2, max: 5 })]}
            />
          </Section>

          {existing ? (
            <Section>
              <Button role="destructive" label="Delete Driver" systemImage="trash" onPress={remove} modifiers={[foregroundStyle('red')]} />
            </Section>
          ) : null}
        </Form>
      </Host>
    </>
  );
}

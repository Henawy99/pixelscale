import { useEffect, useRef, useState } from 'react';
import { Alert } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, Form, HStack, Image, Label, Section, Spacer, Text, TextField } from '@expo/ui/swift-ui';
import {
  autocorrectionDisabled,
  buttonStyle,
  foregroundStyle,
  frame,
  keyboardType,
  lineLimit,
  multilineTextAlignment,
  onSubmit,
  scrollDismissesKeyboard,
  submitLabel,
  textInputAutocapitalization,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { OfferedTour, TourTicket } from '@/types';
import { parseGygUrl } from '@/lib/toursStorage';
import { reviewNotesFor } from '@/lib/tours';
import { openUrl } from '@/lib/links';
import { ACCENT, text, tone } from '@/components/theme';
import { parseAmount, useField } from '@/components/use-field';

type TicketReader = () => TourTicket;

const newId = (prefix: string) => `${prefix}_${Date.now()}_${Math.random().toString(36).slice(2, 6)}`;

export default function TourFormScreen() {
  const params = useLocalSearchParams<{ id?: string; title?: string; url?: string }>();
  const router = useRouter();
  const { offeredTours, bookings, matchTour, saveTour, deleteTour } = useAppData();
  const existing = offeredTours.find((t) => t.id === params.id);

  const link = useField(existing?.gygUrl ?? params.url ?? '');
  const title = useField(existing?.title ?? params.title ?? '');
  const code = useField(existing?.referenceCode ?? '');
  const notes = useField(existing?.notes ?? '');
  const newAlias = useField('');
  const [aliases, setAliases] = useState<string[]>(existing?.aliases ?? []);
  const [tickets, setTickets] = useState<TourTicket[]>(existing?.tickets ?? []);
  // Each ticket row owns its fields; Save reads them synchronously through these readers.
  const readers = useRef(new Map<string, TicketReader>());

  const parsedLink = parseGygUrl(link.value);
  const matchedCount = existing
    ? bookings.filter((b) => b.status !== 'cancelled' && matchTour(b)?.tour.id === existing.id).length
    : 0;

  // A pasted or typed link fills in the title when it's still empty.
  useEffect(() => {
    if (parsedLink && !title.current().trim()) title.set(parsedLink.slugTitle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [parsedLink?.tourId]);

  const pasteLink = async () => {
    const clip = (await Clipboard.getStringAsync()).trim();
    const parsed = parseGygUrl(clip);
    if (!parsed) {
      Alert.alert('No GetYourGuide Link', 'Copy a tour link from GetYourGuide or the Supplier Portal first.');
      return;
    }
    Haptics.selectionAsync();
    link.set(parsed.url);
    if (!title.current().trim()) title.set(parsed.slugTitle);
  };

  const addTicket = () => {
    Haptics.selectionAsync();
    setTickets((list) => [...list, { id: newId('tkt'), name: '', pricePerPassenger: 0 }]);
  };

  const removeTicket = (id: string) => setTickets((list) => list.filter((t) => t.id !== id));

  const addAlias = () => {
    const value = newAlias.current().trim();
    if (!value || aliases.includes(value)) return;
    setAliases((list) => [...list, value]);
    newAlias.set('');
  };

  const buildTour = (): OfferedTour | null => {
    const name = title.current().trim();
    if (!name) {
      Alert.alert('Title Required', 'Enter the tour title exactly as GetYourGuide shows it.');
      return null;
    }
    const rawLink = link.current().trim();
    const parsed = parseGygUrl(rawLink);
    if (rawLink && !parsed) {
      Alert.alert('Invalid Link', 'Use a GetYourGuide tour link ending in -t followed by numbers.');
      return null;
    }
    const pendingAlias = newAlias.current().trim();
    return {
      id: existing?.id ?? (parsed ? `gyg_${parsed.tourId}` : newId('tour')),
      title: name,
      gygUrl: parsed?.url ?? '',
      gygTourId: parsed?.tourId,
      referenceCode: code.current().trim() || undefined,
      location: existing?.location ?? parsed?.location,
      aliases: pendingAlias && !aliases.includes(pendingAlias) ? [...aliases, pendingAlias] : aliases,
      tickets: tickets
        .map((t) => readers.current.get(t.id)?.() ?? t)
        .filter((t) => t.name.trim())
        .map((t) => ({ ...t, name: t.name.trim() })),
      notes: notes.current().trim() || undefined,
      createdAt: existing?.createdAt ?? Date.now(),
    };
  };

  const save = async () => {
    const tour = buildTour();
    if (!tour) return;
    if (!existing && offeredTours.some((t) => t.id === tour.id)) {
      Alert.alert('Already Added', 'This GetYourGuide tour is already in your list.');
      return;
    }
    await saveTour(tour);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    router.back();
  };

  const writeReview = () => {
    const tour = buildTour();
    if (!tour?.gygUrl) {
      Alert.alert('Link Required', 'Add the GetYourGuide link so the review can be written from the tour page.');
      return;
    }
    router.push({ pathname: '/studio', params: { url: tour.gygUrl, notes: reviewNotesFor(tour), autostart: '1' } });
  };

  const remove = () => {
    if (!existing) return;
    Alert.alert(
      'Delete Tour?',
      matchedCount > 0
        ? `${matchedCount} bookings will show as an unknown tour and stop deducting its tickets.`
        : 'You can add it again from its GetYourGuide link.',
      [
        { text: 'Cancel', style: 'cancel' },
        {
          text: 'Delete',
          style: 'destructive',
          onPress: async () => {
            await deleteTour(existing.id);
            Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
            router.back();
          },
        },
      ]
    );
  };

  return (
    <>
      <Stack.Screen options={{ title: existing ? 'Edit Tour' : 'New Tour' }} />
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button onPress={() => router.back()}>Cancel</Stack.Toolbar.Button>
      </Stack.Toolbar>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button variant="done" tintColor={ACCENT} disabled={!title.value.trim()} onPress={save}>
          Save
        </Stack.Toolbar.Button>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <Form modifiers={[scrollDismissesKeyboard('interactively')]}>
          <Section
            title="GetYourGuide"
            footer={
              <Text>
                {parsedLink
                  ? `Tour ID ${parsedLink.tourId}${parsedLink.location ? ` · ${parsedLink.location}` : ''}`
                  : 'Paste the tour link from GetYourGuide or “Preview on website” in the Supplier Portal.'}
              </Text>
            }>
            <TextField
              text={link.state}
              onTextChange={link.onTextChange}
              placeholder="https://www.getyourguide.com/…-t1234567/"
              axis="vertical"
              modifiers={[
                lineLimit({ min: 1, max: 3 }),
                keyboardType('url'),
                textInputAutocapitalization('never'),
                autocorrectionDisabled(),
              ]}
            />
            <Button label="Paste Link" systemImage="doc.on.clipboard" onPress={pasteLink} />
          </Section>

          <Section title="Tour" footer={<Text>Use the reference code from the Supplier Portal, e.g. HALL-5F-GOSAU.</Text>}>
            <TextField
              text={title.state}
              onTextChange={title.onTextChange}
              placeholder="Title as shown on GetYourGuide"
              axis="vertical"
              autoFocus={!existing && !params.title}
              modifiers={[lineLimit({ min: 1, max: 3 })]}
            />
            <TextField
              text={code.state}
              onTextChange={code.onTextChange}
              placeholder="Product reference code"
              modifiers={[textInputAutocapitalization('characters'), autocorrectionDisabled()]}
            />
          </Section>

          <Section
            title="Included Tickets"
            footer={<Text>Bought for every guest. The per-guest price is deducted from each booking’s payout.</Text>}>
            {tickets.map((t) => (
              <TicketEditorRow
                key={t.id}
                ticket={t}
                register={(read) => {
                  readers.current.set(t.id, read);
                  return () => readers.current.delete(t.id);
                }}
                onRemove={() => removeTicket(t.id)}
              />
            ))}
            <Button label="Add Ticket" systemImage="plus.circle.fill" onPress={addTicket} />
          </Section>

          <Section
            title="Also Recognise These Titles"
            footer={
              <Text>
                {existing
                  ? `${matchedCount} bookings recognised. Add old or translated titles that booking emails still use.`
                  : 'Old or translated titles that booking emails still use.'}
              </Text>
            }>
            {aliases.map((a) => (
              <HStack key={a} spacing={10}>
                <Text modifiers={[text.subheadline, text.twoLines, text.primary]}>{a}</Text>
                <Spacer />
                <Button onPress={() => setAliases((list) => list.filter((x) => x !== a))} modifiers={[buttonStyle('borderless')]}>
                  <Image systemName="minus.circle.fill" size={18} color={tone.negative} />
                </Button>
              </HStack>
            ))}
            <TextField
              text={newAlias.state}
              onTextChange={newAlias.onTextChange}
              placeholder="Add a title"
              modifiers={[submitLabel('done'), onSubmit(addAlias)]}
            />
          </Section>

          <Section title="Notes">
            <TextField
              text={notes.state}
              onTextChange={notes.onTextChange}
              placeholder="Meeting points, seasonal changes…"
              axis="vertical"
              modifiers={[lineLimit({ min: 2, max: 5 })]}
            />
          </Section>

          {existing ? (
            <Section>
              <Button onPress={writeReview}>
                <Label title="Write Review for This Tour" systemImage="sparkles" />
              </Button>
              {existing.gygUrl ? (
                <Button onPress={() => openUrl(existing.gygUrl)}>
                  <Label title="Open on GetYourGuide" systemImage="safari" />
                </Button>
              ) : null}
            </Section>
          ) : null}

          {existing ? (
            <Section>
              <Button onPress={remove}>
                <Label title="Delete Tour" systemImage="trash" modifiers={[foregroundStyle('red')]} />
              </Button>
            </Section>
          ) : null}
        </Form>
      </Host>
    </>
  );
}

/** Name and per-guest price of one included ticket. */
function TicketEditorRow({
  ticket,
  register,
  onRemove,
}: {
  ticket: TourTicket;
  register: (read: TicketReader) => () => void;
  onRemove: () => void;
}) {
  const name = useField(ticket.name);
  const price = useField(ticket.pricePerPassenger > 0 ? String(ticket.pricePerPassenger) : '');

  useEffect(
    () =>
      register(() => {
        const n = parseAmount(price.current());
        return {
          id: ticket.id,
          name: name.current(),
          pricePerPassenger: isNaN(n) || n < 0 ? 0 : Math.round(n * 100) / 100,
        };
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [ticket.id]
  );

  return (
    <HStack spacing={8}>
      <Button onPress={onRemove} modifiers={[buttonStyle('borderless')]}>
        <Image systemName="minus.circle.fill" size={18} color={tone.negative} />
      </Button>
      <TextField
        text={name.state}
        onTextChange={name.onTextChange}
        placeholder="Ticket, e.g. Salt Mine entry"
        autoFocus={!ticket.name}
      />
      <TextField
        text={price.state}
        onTextChange={price.onTextChange}
        placeholder="0"
        modifiers={[keyboardType('decimal-pad'), multilineTextAlignment('trailing'), frame({ width: 56 })]}
      />
      <Text modifiers={[text.subheadline, text.secondary]}>€</Text>
    </HStack>
  );
}

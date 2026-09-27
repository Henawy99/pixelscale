import { useEffect, useMemo, useRef } from 'react';
import { Stack, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, HStack, Image, List, Menu, Section, Spacer, Text, TextField, VStack } from '@expo/ui/swift-ui';
import { frame, keyboardType, listStyle, multilineTextAlignment, scrollDismissesKeyboard } from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { OfferedTour, TourTicket, getNumericPrice } from '@/types';
import { formatEur } from '@/lib/finance';
import { getBookingTicketDeduction } from '@/lib/tours';
import { formatDuration, formatPrice, tourContentFor } from '@/lib/itinerary';
import { Stat } from '@/components/primitives';
import { ACCENT, text, tone } from '@/components/theme';
import { parseAmount, useField } from '@/components/use-field';

/**
 * The tour catalog as a pricing dashboard: every GetYourGuide product with the tickets it
 * includes and their per-guest price, which is deducted from each matching booking's payout.
 */
export default function ToursScreen() {
  const router = useRouter();
  const { offeredTours, bookings, matchTour, setTicketPrice, addTourAlias } = useAppData();

  const { bookingCounts, unmatched, ticketSpend } = useMemo(() => {
    const counts: Record<string, number> = {};
    const titles = new Map<string, number>();
    let spend = 0;
    bookings.forEach((b) => {
      if (b.status === 'cancelled') return;
      const match = matchTour(b);
      if (match) counts[match.tour.id] = (counts[match.tour.id] ?? 0) + 1;
      else if (b.tourTitle && getNumericPrice(b) > 0) titles.set(b.tourTitle, (titles.get(b.tourTitle) ?? 0) + 1);
      spend += getBookingTicketDeduction(b, matchTour).totalCost;
    });
    return {
      bookingCounts: counts,
      unmatched: [...titles.entries()].sort((a, b) => b[1] - a[1]),
      ticketSpend: spend,
    };
  }, [bookings, matchTour]);

  const tours = useMemo(
    () => [...offeredTours].sort((a, b) => (bookingCounts[b.id] ?? 0) - (bookingCounts[a.id] ?? 0) || a.title.localeCompare(b.title)),
    [offeredTours, bookingCounts]
  );
  const missingPrices = offeredTours.reduce(
    (n, t) => n + (t.tickets ?? []).filter((k) => !(k.pricePerPassenger > 0)).length,
    0
  );

  const linkTitle = async (tour: OfferedTour, title: string) => {
    await addTourAlias(tour.id, title);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
  };

  return (
    <>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button icon="plus" onPress={() => router.push('/tour-form')} accessibilityLabel="Add Tour" />
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List modifiers={[listStyle('insetGrouped'), scrollDismissesKeyboard('interactively')]}>
          <Section
            footer={
              <Text>
                Ticket prices are per guest and come off each booking’s payout automatically. Review bookings and
                cancellations never buy tickets.
              </Text>
            }>
            <HStack>
              <Stat label="Tours" value={String(offeredTours.length)} />
              <Spacer />
              <Stat label="Tickets bought" value={formatEur(ticketSpend)} />
              <Spacer />
              <Stat
                label="Prices missing"
                value={String(missingPrices)}
                color={missingPrices > 0 ? tone.warning : tone.positive}
              />
            </HStack>
          </Section>

          {unmatched.length > 0 ? (
            <Section
              title="Unrecognised Bookings"
              footer={<Text>Link a title to a tour once and every booking with that title is recognised from now on.</Text>}>
              {unmatched.map(([title, count]) => (
                <HStack key={title} spacing={10}>
                  <VStack alignment="leading" spacing={2}>
                    <Text modifiers={[text.subheadline, text.twoLines, text.primary]}>{title}</Text>
                    <Text modifiers={[text.caption, text.secondary]}>{`${count} ${count === 1 ? 'booking' : 'bookings'}`}</Text>
                  </VStack>
                  <Spacer />
                  <Menu label="Link" systemImage="link">
                    {tours.map((t) => (
                      <Button
                        key={t.id}
                        label={t.referenceCode ? `${t.referenceCode} · ${t.title}` : t.title}
                        onPress={() => linkTitle(t, title)}
                      />
                    ))}
                    <Button
                      label="New Tour from This Title"
                      systemImage="plus"
                      onPress={() => router.push({ pathname: '/tour-form', params: { title } })}
                    />
                  </Menu>
                </HStack>
              ))}
            </Section>
          ) : null}

          {tours.map((tour) => (
            <Section key={tour.id} title={tour.referenceCode || 'No reference code'}>
              <Button onPress={() => router.push({ pathname: '/tours/[id]', params: { id: tour.id } })}>
                <HStack spacing={10}>
                  <VStack alignment="leading" spacing={2}>
                    <Text modifiers={[text.rowTitle, text.twoLines, text.primary]}>{tour.title}</Text>
                    <Text modifiers={[text.caption, text.secondary]}>{tourSummary(tour, bookingCounts[tour.id] ?? 0)}</Text>
                  </VStack>
                  <Spacer />
                  <Image systemName="chevron.right" size={12} color="#C7C7CC" />
                </HStack>
              </Button>
              {(tour.tickets ?? []).length === 0 ? (
                <Text modifiers={[text.footnote, text.secondary]}>No tickets included</Text>
              ) : (
                (tour.tickets ?? []).map((ticket) => (
                  <TicketPriceRow
                    key={ticket.id}
                    ticket={ticket}
                    onSave={(price) => setTicketPrice(tour.id, ticket.id, price)}
                  />
                ))
              )}
            </Section>
          ))}
        </List>
      </Host>
    </>
  );
}

/** "8 h · €250 per person · 08:00 · 12 bookings", or the location for tours added by hand. */
function tourSummary(tour: OfferedTour, bookings: number): string {
  const content = tourContentFor(tour);
  const facts = content
    ? [formatDuration(content.durationMinutes), formatPrice(content.price), content.startTimes[0]]
    : [tour.location];
  return [...facts, `${bookings} ${bookings === 1 ? 'booking' : 'bookings'}`].filter(Boolean).join(' · ');
}

/** One included ticket with an inline per-guest price, saved shortly after typing stops. */
function TicketPriceRow({ ticket, onSave }: { ticket: TourTicket; onSave: (price: number) => void }) {
  const price = useField(ticket.pricePerPassenger > 0 ? String(ticket.pricePerPassenger) : '');
  const lastSaved = useRef(ticket.pricePerPassenger);
  const missing = !(ticket.pricePerPassenger > 0);

  // Decimal pads have no Return key and Forms don't blur on tap, so commit on a pause.
  useEffect(() => {
    const timer = setTimeout(() => {
      const n = parseAmount(price.current());
      const next = isNaN(n) || n < 0 ? 0 : Math.round(n * 100) / 100;
      if (next !== ticket.pricePerPassenger) {
        lastSaved.current = next;
        onSave(next);
      }
    }, 600);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [price.value]);

  // Show prices changed in the tour editor, but never echo our own save back over newer typing.
  useEffect(() => {
    if (ticket.pricePerPassenger === lastSaved.current) return;
    lastSaved.current = ticket.pricePerPassenger;
    price.set(ticket.pricePerPassenger > 0 ? String(ticket.pricePerPassenger) : '');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ticket.pricePerPassenger]);

  return (
    <HStack spacing={8}>
      <Image systemName="ticket" size={14} color={missing ? tone.warning : 'gray'} modifiers={[frame({ width: 20 })]} />
      <Text modifiers={[text.subheadline, text.twoLines, text.primary]}>{ticket.name}</Text>
      <Spacer />
      <TextField
        text={price.state}
        onTextChange={price.onTextChange}
        placeholder="Price"
        modifiers={[keyboardType('decimal-pad'), multilineTextAlignment('trailing'), frame({ width: 56 })]}
      />
      <Text modifiers={[text.caption, text.secondary]}>€ / guest</Text>
    </HStack>
  );
}

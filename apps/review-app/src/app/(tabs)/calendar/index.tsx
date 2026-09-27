import { useMemo, useState } from 'react';
import { Stack } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import {
  Button,
  ContentUnavailableView,
  HStack,
  List,
  Picker,
  Section,
  Text,
  VStack,
  ZStack,
} from '@expo/ui/swift-ui';
import {
  background,
  buttonStyle,
  font,
  foregroundStyle,
  frame,
  listRowBackground,
  listRowInsets,
  listStyle,
  pickerStyle,
  refreshable,
  shapes,
  tag,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { BookingItem, getNumericPrice, isBookingReview, platformFeeRate } from '@/types';
import { getBookingTicketDeduction } from '@/lib/tours';
import {
  addDays,
  bookingDateKey,
  formatLongDay,
  formatWeekRange,
  fromDateKey,
  startOfWeek,
  toDateKey,
  weekdayShort,
} from '@/lib/dates';
import { formatEur } from '@/lib/finance';
import { BookingRow } from '@/components/booking-row';
import { ACCENT, text } from '@/components/theme';

type Mode = 'day' | 'week';

export default function CalendarScreen() {
  const { bookings, drivers, assignments, matchTour, refresh } = useAppData();
  const todayKey = toDateKey(new Date());
  const [monday, setMonday] = useState(() => startOfWeek(new Date()));
  const [selectedKey, setSelectedKey] = useState(todayKey);
  const [mode, setMode] = useState<Mode>('day');

  const byDay = useMemo(() => {
    const map = new Map<string, BookingItem[]>();
    for (const b of bookings) {
      const key = bookingDateKey(b);
      if (!key) continue;
      const list = map.get(key) ?? [];
      list.push(b);
      map.set(key, list);
    }
    map.forEach((list) => list.sort((a, b) => (a.timestamp ?? 0) - (b.timestamp ?? 0)));
    return map;
  }, [bookings]);

  const weekKeys = useMemo(() => Array.from({ length: 7 }, (_, i) => toDateKey(addDays(monday, i))), [monday]);
  const weekBookings = useMemo(() => weekKeys.flatMap((k) => byDay.get(k) ?? []), [weekKeys, byDay]);

  // Week metrics — cancelled tours never count.
  const stats = useMemo(() => {
    let bookingCount = 0;
    let realTours = 0;
    let net = 0;
    let tickets = 0;
    let withDriver = 0;
    for (const b of weekBookings) {
      if (b.status === 'cancelled') continue;
      bookingCount++;
      net += getNumericPrice(b) * (1 - platformFeeRate(b));
      tickets += getBookingTicketDeduction(b, matchTour).totalCost;
      // Only real tours need a driver; review bookings never get one.
      if (!isBookingReview(b)) {
        realTours++;
        if (assignments[b.referenceNumber]) withDriver++;
      }
    }
    return { bookingCount, realTours, net, tickets, profit: Math.max(0, net - tickets), withDriver };
  }, [weekBookings, matchTour, assignments]);

  const shiftWeek = (weeks: number) => {
    Haptics.selectionAsync();
    const next = addDays(monday, weeks * 7);
    setMonday(next);
    setSelectedKey(toDateKey(next));
  };

  const goToday = () => {
    Haptics.selectionAsync();
    setMonday(startOfWeek(new Date()));
    setSelectedKey(todayKey);
  };

  const rowProps = (b: BookingItem) => ({
    booking: b,
    drivers,
    assignment: assignments[b.referenceNumber],
    leading: 'time' as const,
  });

  const dayBookings = byDay.get(selectedKey) ?? [];

  return (
    <>
      <Stack.Screen options={{ title: formatWeekRange(monday) }} />
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button icon="chevron.left" onPress={() => shiftWeek(-1)} accessibilityLabel="Previous week" />
      </Stack.Toolbar>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button onPress={goToday}>Today</Stack.Toolbar.Button>
        <Stack.Toolbar.Button icon="chevron.right" onPress={() => shiftWeek(1)} accessibilityLabel="Next week" />
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List
          modifiers={[
            listStyle('insetGrouped'),
            refreshable(async () => {
              await refresh();
            }),
          ]}>
          {/* Week strip */}
          <Section>
            <HStack spacing={0}>
              {weekKeys.map((key) => {
                const date = fromDateKey(key);
                const count = (byDay.get(key) ?? []).filter((b) => b.status !== 'cancelled').length;
                const isSelected = mode === 'day' && key === selectedKey;
                const isToday = key === todayKey;
                return (
                  <Button
                    key={key}
                    onPress={() => {
                      Haptics.selectionAsync();
                      setSelectedKey(key);
                      setMode('day');
                    }}
                    modifiers={[buttonStyle('plain'), frame({ maxWidth: Infinity })]}>
                    <VStack spacing={5} modifiers={[frame({ maxWidth: Infinity })]}>
                      <Text modifiers={[text.caption2, isToday ? foregroundStyle(ACCENT) : text.secondary]}>
                        {weekdayShort(date).slice(0, 3)}
                      </Text>
                      <ZStack
                        modifiers={[
                          frame({ width: 36, height: 36 }),
                          background(isSelected ? ACCENT : 'clear', shapes.circle()),
                        ]}>
                        <Text
                          modifiers={[
                            font({ size: 17, weight: isSelected || isToday ? 'bold' : 'regular' }),
                            text.digits,
                            isSelected ? foregroundStyle('white') : isToday ? foregroundStyle(ACCENT) : text.primary,
                          ]}>
                          {String(date.getDate())}
                        </Text>
                      </ZStack>
                      <Text modifiers={[text.caption2, text.digits, count > 0 ? text.secondary : foregroundStyle('clear')]}>
                        {count > 0 ? `${count}` : '0'}
                      </Text>
                    </VStack>
                  </Button>
                );
              })}
            </HStack>
          </Section>

          {/* Week at a glance */}
          <Section>
            <HStack spacing={0}>
              <Metric label="Bookings" value={String(stats.bookingCount)} />
              <Metric label={stats.tickets > 0 ? 'Net profit' : 'Net payout'} value={formatEur(stats.tickets > 0 ? stats.profit : stats.net)} />
              <Metric label="Tours with driver" value={`${stats.withDriver}/${stats.realTours}`} />
            </HStack>
          </Section>

          <Section modifiers={[listRowBackground('clear'), listRowInsets({ top: 0, leading: 0, bottom: 0, trailing: 0 })]}>
            <Picker selection={mode} onSelectionChange={(v) => setMode(v as Mode)} modifiers={[pickerStyle('segmented')]}>
              <Text modifiers={[tag('day')]}>Day</Text>
              <Text modifiers={[tag('week')]}>Whole Week</Text>
            </Picker>
          </Section>

          {mode === 'day' ? (
            <Section title={formatLongDay(fromDateKey(selectedKey))}>
              {dayBookings.length === 0 ? (
                <ContentUnavailableView title="No Tours" systemImage="calendar" description="Nothing is booked on this day." />
              ) : (
                dayBookings.map((b) => <BookingRow key={b.id || b.referenceNumber} {...rowProps(b)} />)
              )}
            </Section>
          ) : weekBookings.length === 0 ? (
            <Section>
              <ContentUnavailableView title="No Tours This Week" systemImage="calendar" />
            </Section>
          ) : (
            weekKeys
              .filter((k) => (byDay.get(k) ?? []).length > 0)
              .map((k) => (
                <Section key={k} title={formatLongDay(fromDateKey(k))}>
                  {(byDay.get(k) ?? []).map((b) => (
                    <BookingRow key={b.id || b.referenceNumber} {...rowProps(b)} />
                  ))}
                </Section>
              ))
          )}
        </List>
      </Host>
    </>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <VStack spacing={2} modifiers={[frame({ maxWidth: Infinity })]}>
      <Text modifiers={[text.headline, text.digits]}>{value}</Text>
      <Text modifiers={[text.caption, text.secondary]}>{label}</Text>
    </VStack>
  );
}

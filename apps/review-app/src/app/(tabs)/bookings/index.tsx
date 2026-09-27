import { useMemo, useState } from 'react';
import { Stack, useRouter } from 'expo-router';
import { Host } from '@expo/ui';
import {
  Button,
  ContentUnavailableView,
  HStack,
  Image,
  List,
  Picker,
  ProgressView,
  Section,
  Spacer,
  Text,
  VStack,
} from '@expo/ui/swift-ui';
import {
  foregroundStyle,
  listRowBackground,
  listRowInsets,
  listStyle,
  pickerStyle,
  refreshable,
  tag,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { BookingItem, isBookingReview } from '@/types';
import { computeRevenue, formatEur, statsForMonth } from '@/lib/finance';
import { currentMonthLabel, formatRelative, groupBookingsByDate } from '@/lib/dates';
import { syncSourceLabel } from '@/lib/labels';
import { BookingRow } from '@/components/booking-row';
import { ACCENT, text } from '@/components/theme';

type Category = 'tours' | 'reviews' | 'all';
type PlatformFilter = 'all' | 'gyg' | 'airbnb';
type StatusFilter = 'any' | 'confirmed' | 'last-minute' | 'cancelled';

function matchesFilters(b: BookingItem, category: Category, platform: PlatformFilter, status: StatusFilter) {
  const isReview = isBookingReview(b);
  const isCancelled = b.status === 'cancelled';

  if (category === 'tours' && isReview) return false;
  if (category === 'reviews' && !isReview) return false;

  if (status === 'any' && category !== 'all' && isCancelled) return false;
  if (status === 'confirmed' && b.status !== 'confirmed') return false;
  if (status === 'last-minute' && (!b.isLastMinute || isCancelled)) return false;
  if (status === 'cancelled' && !isCancelled) return false;

  if (platform === 'airbnb' && b.platform !== 'airbnb') return false;
  if (platform === 'gyg' && b.platform === 'airbnb') return false;
  return true;
}

function matchesQuery(b: BookingItem, q: string) {
  if (!q) return true;
  return [b.referenceNumber, b.tourTitle, b.customerName, b.customerPhone, b.pickup]
    .some((field) => (field || '').toLowerCase().includes(q));
}

export default function BookingsScreen() {
  const router = useRouter();
  const { bookings, drivers, assignments, matchTour, sync, refresh } = useAppData();

  const [query, setQuery] = useState('');
  const [category, setCategory] = useState<Category>('tours');
  const [platform, setPlatform] = useState<PlatformFilter>('all');
  const [status, setStatus] = useState<StatusFilter>('any');
  const [showPast, setShowPast] = useState(false);

  const q = query.trim().toLowerCase();
  const filtersActive = platform !== 'all' || status !== 'any';

  const counts = useMemo(() => {
    const count = (c: Category) => bookings.filter((b) => matchesFilters(b, c, platform, status)).length;
    return { tours: count('tours'), reviews: count('reviews'), all: count('all') };
  }, [bookings, platform, status]);

  const visible = useMemo(
    () => bookings.filter((b) => matchesFilters(b, category, platform, status) && matchesQuery(b, q)),
    [bookings, category, platform, status, q]
  );
  const { upcoming, past } = useMemo(() => groupBookingsByDate(visible), [visible]);

  const month = currentMonthLabel();
  const monthStats = useMemo(
    () => statsForMonth(computeRevenue(bookings, matchTour), month),
    [bookings, matchTour, month]
  );
  const headline = monthStats.ticketCosts > 0 ? monthStats.profit : monthStats.net;

  const sourceLabel = syncSourceLabel(sync.source);

  const rowProps = (b: BookingItem) => ({
    booking: b,
    drivers,
    assignment: assignments[b.referenceNumber],
  });

  const showPastRows = showPast || q.length > 0;

  return (
    <>
      <Stack.SearchBar
        placeholder="Reference, customer, tour, pickup"
        onChangeText={(e) => setQuery(e.nativeEvent.text)}
        onCancelButtonPress={() => setQuery('')}
      />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Menu
          icon={filtersActive ? 'line.3.horizontal.decrease.circle.fill' : 'line.3.horizontal.decrease.circle'}
          accessibilityLabel="Filter bookings">
          <Stack.Toolbar.Menu inline title="Platform">
            <Stack.Toolbar.MenuAction isOn={platform === 'all'} onPress={() => setPlatform('all')}>
              All Platforms
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction isOn={platform === 'gyg'} onPress={() => setPlatform('gyg')}>
              GetYourGuide
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction isOn={platform === 'airbnb'} onPress={() => setPlatform('airbnb')}>
              Airbnb
            </Stack.Toolbar.MenuAction>
          </Stack.Toolbar.Menu>
          <Stack.Toolbar.Menu inline title="Status">
            <Stack.Toolbar.MenuAction isOn={status === 'any'} onPress={() => setStatus('any')}>
              Any Status
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction isOn={status === 'confirmed'} onPress={() => setStatus('confirmed')}>
              Confirmed
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction isOn={status === 'last-minute'} onPress={() => setStatus('last-minute')}>
              Last Minute
            </Stack.Toolbar.MenuAction>
            <Stack.Toolbar.MenuAction isOn={status === 'cancelled'} onPress={() => setStatus('cancelled')}>
              Cancelled
            </Stack.Toolbar.MenuAction>
          </Stack.Toolbar.Menu>
        </Stack.Toolbar.Menu>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List
          modifiers={[
            listStyle('insetGrouped'),
            refreshable(async () => {
              await refresh();
            }),
          ]}>
          {/* Month at a glance */}
          <Section
            footer={
              sync.error ? (
                <Text modifiers={[foregroundStyle('red')]}>{sync.error}</Text>
              ) : (
                <Text>
                  {sourceLabel ? `${sourceLabel} · ` : ''}
                  {sync.lastSyncedAt ? `Updated ${formatRelative(sync.lastSyncedAt)}` : 'Not synced yet'}
                </Text>
              )
            }>
            <Button onPress={() => router.push('/bookings/revenue')}>
              <HStack spacing={12}>
                <VStack alignment="leading" spacing={2}>
                  <Text modifiers={[text.caption, text.secondary]}>
                    {`${monthStats.ticketCosts > 0 ? 'Net profit' : 'Net payout'} · ${month}`}
                  </Text>
                  <Text modifiers={[text.largeNumber, text.digits, text.primary]}>{formatEur(headline)}</Text>
                  <Text modifiers={[text.footnote, text.secondary]}>
                    {`${monthStats.count} bookings · ${formatEur(monthStats.gross)} gross`}
                  </Text>
                </VStack>
                <Spacer />
                {sync.isSyncing ? <ProgressView /> : null}
                <Image systemName="chevron.right" size={13} color="#C7C7CC" />
              </HStack>
            </Button>
          </Section>

          {/* Category switch */}
          <Section modifiers={[listRowBackground('clear'), listRowInsets({ top: 0, leading: 0, bottom: 0, trailing: 0 })]}>
            <Picker
              selection={category}
              onSelectionChange={(v) => setCategory(v as Category)}
              modifiers={[pickerStyle('segmented')]}>
              <Text modifiers={[tag('tours')]}>{`Tours ${counts.tours}`}</Text>
              <Text modifiers={[tag('reviews')]}>{`Reviews ${counts.reviews}`}</Text>
              <Text modifiers={[tag('all')]}>{`All ${counts.all}`}</Text>
            </Picker>
          </Section>

          {sync.isLoading && bookings.length === 0 ? (
            <Section>
              <HStack spacing={10}>
                <ProgressView />
                <Text modifiers={[text.secondary]}>Loading bookings from your inbox…</Text>
              </HStack>
            </Section>
          ) : visible.length === 0 ? (
            <Section>
              <ContentUnavailableView
                title={q ? 'No Results' : 'No Bookings'}
                systemImage={q ? 'magnifyingglass' : 'tray'}
                description={
                  q ? `Nothing matches “${query.trim()}”.` : 'Try another category or clear the filters.'
                }
              />
            </Section>
          ) : null}

          {upcoming.map((group) => (
            <Section key={group.key} title={`${group.title} · ${group.items.length}`}>
              {group.items.map((b) => (
                <BookingRow key={b.id || b.referenceNumber} {...rowProps(b)} />
              ))}
            </Section>
          ))}

          {past.length > 0 ? (
            <Section title={`Past · ${past.length}`}>
              {showPastRows ? (
                past.map((b) => <BookingRow key={b.id || b.referenceNumber} {...rowProps(b)} />)
              ) : (
                <Button
                  label={`Show ${past.length} past ${past.length === 1 ? 'booking' : 'bookings'}`}
                  systemImage="clock.arrow.circlepath"
                  onPress={() => setShowPast(true)}
                />
              )}
            </Section>
          ) : null}
        </List>
      </Host>
    </>
  );
}

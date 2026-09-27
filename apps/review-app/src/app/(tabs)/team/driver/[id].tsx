import { useMemo } from 'react';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Host } from '@expo/ui';
import {
  Button,
  ContentUnavailableView,
  HStack,
  Image,
  List,
  Section,
  Spacer,
  Text,
  VStack,
} from '@expo/ui/swift-ui';
import { frame, listStyle, opacity, strikethrough } from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { computeDriverStatistics } from '@/lib/driverStorage';
import { bookingDate, monthShort } from '@/lib/dates';
import { driverRateLabel, formatEur } from '@/lib/finance';
import { callPhone } from '@/lib/links';
import { Avatar, Stat } from '@/components/primitives';
import { ACCENT, text, tone } from '@/components/theme';

export default function DriverScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { drivers, bookings, assignments } = useAppData();
  const driver = drivers.find((d) => d.id === id);
  const stats = useMemo(
    () => (driver ? computeDriverStatistics(driver, bookings, assignments) : null),
    [driver, bookings, assignments]
  );

  if (!driver || !stats) {
    return (
      <Host style={{ flex: 1 }}>
        <ContentUnavailableView title="Driver Not Found" systemImage="person.crop.circle.badge.questionmark" />
      </Host>
    );
  }

  return (
    <>
      <Stack.Screen options={{ title: driver.name }} />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button onPress={() => router.push({ pathname: '/driver-form', params: { id: driver.id } })}>
          Edit
        </Stack.Toolbar.Button>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List modifiers={[listStyle('insetGrouped')]}>
          <Section>
            <HStack spacing={14}>
              <Avatar name={driver.name} color={driver.color} size={52} />
              <VStack alignment="leading" spacing={3}>
                <Text modifiers={[text.title]}>{driver.name}</Text>
                <Text modifiers={[text.footnote, text.secondary]}>{driverRateLabel(driver)}</Text>
                {driver.notes ? <Text modifiers={[text.footnote, text.secondary]}>{driver.notes}</Text> : null}
              </VStack>
            </HStack>
            {driver.phone ? (
              <Button label={`Call ${driver.phone}`} systemImage="phone.fill" onPress={() => callPhone(driver.phone)} />
            ) : null}
          </Section>

          <Section title="Earnings">
            <HStack>
              <Stat label="Total" value={formatEur(stats.totalEarnings)} color={tone.positive} />
              <Spacer />
              <Stat label="Upcoming" value={String(stats.upcomingCount)} />
              <Spacer />
              <Stat label="Done" value={String(stats.completedCount)} />
              <Spacer />
              <Stat label="Cancelled" value={String(stats.cancelledToursCount)} />
            </HStack>
          </Section>

          <Section
            title={`Assigned Tours · ${stats.tours.length}`}
            footer={
              stats.tours.length === 0 ? (
                <Text>{`Open any tour in Bookings or Calendar and pick ${driver.name.split(' ')[0]} as the driver.`}</Text>
              ) : undefined
            }>
            {stats.tours.map(({ booking, payout, isCancelled }) => {
              const date = bookingDate(booking);
              return (
                <Button
                  key={booking.referenceNumber}
                  onPress={() => router.push(`/booking/${encodeURIComponent(booking.referenceNumber)}`)}>
                  <HStack spacing={12} modifiers={isCancelled ? [opacity(0.55)] : []}>
                    <VStack spacing={0} modifiers={[frame({ width: 34 })]}>
                      <Text modifiers={[text.headline, text.digits, text.primary]}>{date ? String(date.getDate()) : '?'}</Text>
                      <Text modifiers={[text.caption2, text.secondary]}>{date ? monthShort(date) : ''}</Text>
                    </VStack>
                    <VStack alignment="leading" spacing={2}>
                      <Text modifiers={[text.subheadline, text.twoLines, text.primary]}>{booking.tourTitle}</Text>
                      <Text modifiers={[text.caption, text.secondary]}>{booking.customerName || booking.referenceNumber}</Text>
                    </VStack>
                    <Spacer />
                    <Text
                      modifiers={[
                        text.rowTitle,
                        text.digits,
                        isCancelled ? text.secondary : text.primary,
                        ...(isCancelled ? [strikethrough({ isActive: true, pattern: 'solid' })] : []),
                      ]}>
                      {formatEur(payout)}
                    </Text>
                    <Image systemName="chevron.right" size={12} color="#C7C7CC" />
                  </HStack>
                </Button>
              );
            })}
          </Section>
        </List>
      </Host>
    </>
  );
}

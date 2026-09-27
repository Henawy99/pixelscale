import { useMemo } from 'react';
import { NativeTabs } from 'expo-router/unstable-native-tabs';
import { useAppData } from '@/state/app-data';
import { isBookingReview } from '@/types';
import { bookingDate, startOfDay } from '@/lib/dates';
import { ACCENT } from '@/components/theme';

export default function TabsLayout() {
  const { bookings, assignments } = useAppData();

  // Badge = real tours in the next 7 days that still need a driver.
  const needsDriver = useMemo(() => {
    const from = startOfDay(new Date()).getTime();
    const to = from + 7 * 86_400_000;
    return bookings.filter((b) => {
      if (b.status === 'cancelled' || isBookingReview(b) || assignments[b.referenceNumber]) return false;
      const t = bookingDate(b)?.getTime();
      return t !== undefined && t >= from && t < to;
    }).length;
  }, [bookings, assignments]);

  return (
    <NativeTabs tintColor={ACCENT}>
      <NativeTabs.Trigger name="bookings">
        <NativeTabs.Trigger.Label>Bookings</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'list.bullet.rectangle', selected: 'list.bullet.rectangle.fill' }} md="list_alt" />
        {needsDriver > 0 ? <NativeTabs.Trigger.Badge>{String(needsDriver)}</NativeTabs.Trigger.Badge> : null}
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="calendar">
        <NativeTabs.Trigger.Label>Calendar</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf="calendar" md="calendar_month" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="team">
        <NativeTabs.Trigger.Label>Team</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'person.2', selected: 'person.2.fill' }} md="group" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="reviews">
        <NativeTabs.Trigger.Label>Reviews</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'star.bubble', selected: 'star.bubble.fill' }} md="reviews" />
      </NativeTabs.Trigger>
      <NativeTabs.Trigger name="settings">
        <NativeTabs.Trigger.Label>Settings</NativeTabs.Trigger.Label>
        <NativeTabs.Trigger.Icon sf={{ default: 'gearshape', selected: 'gearshape.fill' }} md="settings" />
      </NativeTabs.Trigger>
    </NativeTabs>
  );
}

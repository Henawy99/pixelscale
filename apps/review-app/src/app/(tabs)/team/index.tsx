import { useMemo } from 'react';
import { Alert } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, HStack, Image, List, Section, Spacer, SwipeActions, Text, VStack } from '@expo/ui/swift-ui';
import { listStyle, tint } from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { Driver, Reviewer } from '@/types';
import { computeDriverStatistics } from '@/lib/driverStorage';
import { shareToWhatsApp } from '@/lib/reviewerStorage';
import { driverRateLabel, formatEur } from '@/lib/finance';
import { Avatar } from '@/components/primitives';
import { ACCENT, text } from '@/components/theme';

export default function TeamScreen() {
  const router = useRouter();
  const { bookings, drivers, assignments, reviewers, reviewerAssignments, deleteDriver, deleteReviewer } = useAppData();

  const driverStats = useMemo(
    () => drivers.map((d) => computeDriverStatistics(d, bookings, assignments)),
    [drivers, bookings, assignments]
  );
  const totals = useMemo(
    () =>
      driverStats.reduce(
        (acc, s) => ({
          earnings: acc.earnings + s.totalEarnings,
          tours: acc.tours + s.activeToursCount,
          upcoming: acc.upcoming + s.upcomingCount,
        }),
        { earnings: 0, tours: 0, upcoming: 0 }
      ),
    [driverStats]
  );

  const reviewerBookingCount = (id: string) =>
    Object.values(reviewerAssignments).filter((a) => a.reviewerId === id).length;

  const confirmDeleteDriver = (d: Driver) =>
    Alert.alert(`Delete ${d.name}?`, 'Their tours become unassigned and their earnings are removed.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
          await deleteDriver(d.id);
        },
      },
    ]);

  const confirmDeleteReviewer = (r: Reviewer) =>
    Alert.alert(`Delete ${r.name}?`, 'They are also detached from any review bookings.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
          await deleteReviewer(r.id);
        },
      },
    ]);

  const chatWith = (r: Reviewer) => {
    const phone = r.whatsappPhone || r.phone;
    if (!phone) {
      Alert.alert('No Phone Number', `Add a WhatsApp number for ${r.name} first.`);
      return;
    }
    shareToWhatsApp(phone, `Hi ${r.name}! We have some new tour reviews to organize.`);
  };

  return (
    <>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Menu icon="plus" accessibilityLabel="Add">
          <Stack.Toolbar.MenuAction icon="car" onPress={() => router.push('/driver-form')}>
            Add Driver
          </Stack.Toolbar.MenuAction>
          <Stack.Toolbar.MenuAction icon="person.badge.plus" onPress={() => router.push('/reviewer-form')}>
            Add Review Person
          </Stack.Toolbar.MenuAction>
        </Stack.Toolbar.Menu>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List modifiers={[listStyle('insetGrouped')]}>
          <Section footer={<Text>Cancelled tours never count toward driver earnings.</Text>}>
            <VStack alignment="leading" spacing={4}>
              <Text modifiers={[text.caption, text.secondary]}>Driver earnings</Text>
              <Text modifiers={[text.largeNumber, text.digits]}>{formatEur(totals.earnings)}</Text>
              <Text modifiers={[text.footnote, text.secondary]}>
                {`${totals.tours} assigned ${totals.tours === 1 ? 'tour' : 'tours'} · ${totals.upcoming} upcoming`}
              </Text>
            </VStack>
          </Section>

          <Section title={`Drivers · ${drivers.length}`}>
            {driverStats.map(({ driver, totalEarnings, upcomingCount }) => (
              <SwipeActions key={driver.id}>
                <Button onPress={() => router.push(`/team/driver/${driver.id}`)}>
                  <HStack spacing={12}>
                    <Avatar name={driver.name} color={driver.color} />
                    <VStack alignment="leading" spacing={2}>
                      <Text modifiers={[text.rowTitle, text.primary]}>{driver.name}</Text>
                      <Text modifiers={[text.footnote, text.secondary]}>{driverRateLabel(driver)}</Text>
                    </VStack>
                    <Spacer />
                    <VStack alignment="trailing" spacing={2}>
                      <Text modifiers={[text.rowTitle, text.digits, text.primary]}>{formatEur(totalEarnings)}</Text>
                      <Text modifiers={[text.caption, text.secondary]}>{`${upcomingCount} upcoming`}</Text>
                    </VStack>
                    <Image systemName="chevron.right" size={12} color="#C7C7CC" />
                  </HStack>
                </Button>
                <SwipeActions.Actions edge="trailing" allowsFullSwipe={false}>
                  <Button label="Delete" systemImage="trash" onPress={() => confirmDeleteDriver(driver)} modifiers={[tint('red')]} />
                  <Button
                    label="Edit"
                    systemImage="pencil"
                    onPress={() => router.push({ pathname: '/driver-form', params: { id: driver.id } })}
                    modifiers={[tint('gray')]}
                  />
                </SwipeActions.Actions>
              </SwipeActions>
            ))}
            <Button label="Add Driver" systemImage="plus.circle.fill" onPress={() => router.push('/driver-form')} />
          </Section>

          <Section
            title={`Review People · ${reviewers.length}`}
            footer={<Text>Attach them to review bookings and send the review text and photos on WhatsApp.</Text>}>
            {reviewers.map((r) => {
              const count = reviewerBookingCount(r.id);
              return (
                <SwipeActions key={r.id}>
                  <Button onPress={() => router.push({ pathname: '/reviewer-form', params: { id: r.id } })}>
                    <HStack spacing={12}>
                      <Avatar name={r.name} color={r.color} />
                      <VStack alignment="leading" spacing={2}>
                        <Text modifiers={[text.rowTitle, text.primary]}>{r.name}</Text>
                        <Text modifiers={[text.footnote, text.secondary]}>{r.whatsappPhone || r.phone || 'No phone number'}</Text>
                      </VStack>
                      <Spacer />
                      <Text modifiers={[text.caption, text.secondary]}>{count === 1 ? '1 booking' : `${count} bookings`}</Text>
                      <Image systemName="chevron.right" size={12} color="#C7C7CC" />
                    </HStack>
                  </Button>
                  <SwipeActions.Actions edge="leading">
                    <Button label="WhatsApp" systemImage="message.fill" onPress={() => chatWith(r)} modifiers={[tint('green')]} />
                  </SwipeActions.Actions>
                  <SwipeActions.Actions edge="trailing" allowsFullSwipe={false}>
                    <Button label="Delete" systemImage="trash" onPress={() => confirmDeleteReviewer(r)} modifiers={[tint('red')]} />
                  </SwipeActions.Actions>
                </SwipeActions>
              );
            })}
            <Button label="Add Review Person" systemImage="plus.circle.fill" onPress={() => router.push('/reviewer-form')} />
          </Section>
        </List>
      </Host>
    </>
  );
}

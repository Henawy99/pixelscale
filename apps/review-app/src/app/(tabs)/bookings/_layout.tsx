import { Stack } from 'expo-router';
import { useHeaderOptions } from '@/components/theme';

export default function BookingsLayout() {
  const headerOptions = useHeaderOptions();
  return (
    <Stack screenOptions={headerOptions}>
      <Stack.Screen name="index" options={{ title: 'Bookings', headerLargeTitleEnabled: true }} />
      <Stack.Screen name="revenue" options={{ title: 'Revenue' }} />
    </Stack>
  );
}

import { Stack } from 'expo-router';
import { useHeaderOptions } from '@/components/theme';

export default function TeamLayout() {
  const headerOptions = useHeaderOptions();
  return (
    <Stack screenOptions={headerOptions}>
      <Stack.Screen name="index" options={{ title: 'Team', headerLargeTitleEnabled: true }} />
      <Stack.Screen name="driver/[id]" options={{ title: 'Driver' }} />
    </Stack>
  );
}

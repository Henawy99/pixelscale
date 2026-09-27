import { Stack } from 'expo-router';
import { useHeaderOptions } from '@/components/theme';

export default function CalendarLayout() {
  const headerOptions = useHeaderOptions();
  return (
    <Stack screenOptions={headerOptions}>
      <Stack.Screen name="index" options={{ title: 'Calendar', headerLargeTitleEnabled: true }} />
    </Stack>
  );
}

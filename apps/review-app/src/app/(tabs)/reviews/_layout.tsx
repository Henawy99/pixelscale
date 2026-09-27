import { Stack } from 'expo-router';
import { useHeaderOptions } from '@/components/theme';

export default function ReviewsLayout() {
  const headerOptions = useHeaderOptions();
  return (
    <Stack screenOptions={headerOptions}>
      <Stack.Screen name="index" options={{ title: 'Reviews', headerLargeTitleEnabled: true }} />
      <Stack.Screen name="history/[id]" options={{ title: 'Review' }} />
    </Stack>
  );
}

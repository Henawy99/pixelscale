import { Stack } from 'expo-router';
import { useHeaderOptions } from '@/components/theme';

export default function SettingsLayout() {
  const headerOptions = useHeaderOptions();
  return (
    <Stack screenOptions={headerOptions}>
      <Stack.Screen name="index" options={{ title: 'Settings', headerLargeTitleEnabled: true }} />
      <Stack.Screen name="gmail" options={{ title: 'Gmail' }} />
      <Stack.Screen name="zoho" options={{ title: 'Zoho Mail' }} />
      <Stack.Screen name="server" options={{ title: 'Server & AI' }} />
    </Stack>
  );
}

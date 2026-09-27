import { useEffect, useState } from 'react';
import { Platform, Text, View } from 'react-native';
import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { AppDataProvider } from '@/state/app-data';
import { ensureStorageReady } from '@/lib/storage';
import { useHeaderOptions } from '@/components/theme';

export default function RootLayout() {
  const [ready, setReady] = useState(false);
  const headerOptions = useHeaderOptions();

  useEffect(() => {
    ensureStorageReady().finally(() => setReady(true));
  }, []);

  if (Platform.OS !== 'ios') {
    // The interface is built with SwiftUI through Expo UI, which only exists on Apple platforms.
    return (
      <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32 }}>
        <Text style={{ textAlign: 'center' }}>PixelReview currently runs on iOS only.</Text>
      </View>
    );
  }

  if (!ready) return null;

  return (
    <AppDataProvider>
      <StatusBar style="auto" />
      <Stack screenOptions={headerOptions}>
        <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
        <Stack.Screen name="booking/[ref]" options={{ presentation: 'modal', title: 'Booking' }} />
        <Stack.Screen name="studio" options={{ presentation: 'modal', title: 'Write a Review' }} />
        <Stack.Screen name="photo" options={{ presentation: 'modal', title: 'Photo' }} />
        <Stack.Screen name="driver-form" options={{ presentation: 'modal' }} />
        <Stack.Screen name="reviewer-form" options={{ presentation: 'modal' }} />
        <Stack.Screen name="tour-form" options={{ presentation: 'modal' }} />
        <Stack.Screen name="tours/index" options={{ title: 'Tours & Tickets', headerBackButtonDisplayMode: 'minimal' }} />
        <Stack.Screen name="tours/[id]" options={{ title: 'Tour', headerBackButtonDisplayMode: 'minimal' }} />
      </Stack>
    </AppDataProvider>
  );
}

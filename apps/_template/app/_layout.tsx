import React from 'react';
import { Slot } from 'expo-router';
import { PaperProvider, MD3LightTheme } from 'react-native-paper';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { StatusBar } from 'expo-status-bar';

export default function RootLayout() {
  return (
    <SafeAreaProvider>
      <PaperProvider theme={MD3LightTheme}>
        <StatusBar style="dark" />
        <Slot />
      </PaperProvider>
    </SafeAreaProvider>
  );
}

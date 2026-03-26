import React from 'react';
import { View, StyleSheet } from 'react-native';
import { Text, Button, useTheme, Icon } from 'react-native-paper';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function HomeScreen() {
  const theme = useTheme();

  return (
    <SafeAreaView style={[styles.container, { backgroundColor: theme.colors.background }]}>
      <View style={styles.content}>
        <Icon source="rocket-launch" size={64} color={theme.colors.primary} />
        <Text variant="headlineLarge" style={{ fontWeight: '800', marginTop: 16 }}>
          TEMPLATE_NAME
        </Text>
        <Text variant="bodyLarge" style={{ color: theme.colors.onSurfaceVariant, marginTop: 8 }}>
          Your new PixelScale app is ready!
        </Text>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1 },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 24,
  },
});

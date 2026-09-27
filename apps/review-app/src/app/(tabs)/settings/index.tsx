import { useCallback, useState } from 'react';
import { Alert } from 'react-native';
import { type Href, useFocusEffect, useRouter } from 'expo-router';
import Constants from 'expo-constants';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, HStack, List, ProgressView, Section, Spacer, Text } from '@expo/ui/swift-ui';
import { disabled, listStyle } from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { DEFAULT_API_URL, getApiBaseUrl, getGeminiKey, getGmailConfig, getZohoConfig } from '@/api/client';
import { formatRelative } from '@/lib/dates';
import { syncSourceLabel } from '@/lib/labels';
import { NavRow, ValueRow } from '@/components/primitives';
import { ACCENT, text } from '@/components/theme';

export default function SettingsScreen() {
  const router = useRouter();
  const { bookings, sync, refresh } = useAppData();
  const [summary, setSummary] = useState({ gmail: '', zoho: '', server: '', customKey: false });
  const [testing, setTesting] = useState(false);

  // Re-read stored connection details whenever the screen comes back into view.
  useFocusEffect(
    useCallback(() => {
      (async () => {
        const [gmail, zoho, api, key] = await Promise.all([getGmailConfig(), getZohoConfig(), getApiBaseUrl(), getGeminiKey()]);
        setSummary({
          gmail: gmail?.email ?? '',
          zoho: zoho?.email ?? '',
          server: api === DEFAULT_API_URL ? 'Default' : api.replace(/^https?:\/\//, ''),
          customKey: !!key,
        });
      })();
    }, [])
  );

  const syncNow = async () => {
    Haptics.impactAsync(Haptics.ImpactFeedbackStyle.Medium);
    setTesting(true);
    const result = await refresh();
    setTesting(false);
    if (result.ok) {
      Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
      Alert.alert('Sync Complete', `${result.data.total} bookings from ${syncSourceLabel(result.data.source) ?? 'the server'}.`);
    } else {
      Alert.alert('Sync Failed', result.error);
    }
  };

  const version = `${Constants.expoConfig?.version ?? '1.0.0'} (${Constants.expoConfig?.ios?.buildNumber ?? '—'})`;

  return (
    <Host style={{ flex: 1 }} seedColor={ACCENT}>
      <List modifiers={[listStyle('insetGrouped')]}>
        <Section footer={<Text>Your offered tours, their links and the tickets deducted per passenger.</Text>}>
          <NavRow icon="ticket.fill" iconColor="#FF9500" title="Tours & Tickets" onPress={() => router.push('/tours' as Href)} />
        </Section>

        <Section title="Email Sync" footer={<Text>Airbnb emails arrive in Gmail, GetYourGuide emails in Zoho. Both become bookings automatically.</Text>}>
          <NavRow
            icon="envelope.fill"
            iconColor="#FF385C"
            title="Gmail"
            value={summary.gmail || 'Not set'}
            onPress={() => router.push('/settings/gmail')}
          />
          <NavRow
            icon="tray.full.fill"
            iconColor="#34C759"
            title="Zoho Mail"
            value={summary.zoho || 'Default'}
            onPress={() => router.push('/settings/zoho')}
          />
        </Section>

        <Section title="AI & Server">
          <NavRow
            icon="sparkles"
            iconColor="#5856D6"
            title="Server & Gemini Key"
            value={summary.customKey ? `${summary.server} · own key` : summary.server}
            onPress={() => router.push('/settings/server')}
          />
        </Section>

        <Section title="Sync">
          <ValueRow title="Source" value={syncSourceLabel(sync.source) ?? '—'} />
          <ValueRow title="Last synced" value={sync.lastSyncedAt ? formatRelative(sync.lastSyncedAt) : 'Never'} />
          <ValueRow title="Bookings" value={String(bookings.length)} />
          {sync.error ? <Text modifiers={[text.footnote, text.secondary]}>{sync.error}</Text> : null}
          <Button onPress={syncNow} modifiers={[disabled(testing)]}>
            <HStack spacing={8}>
              <Text>{testing ? 'Syncing…' : 'Sync Now'}</Text>
              <Spacer />
              {testing ? <ProgressView /> : null}
            </HStack>
          </Button>
        </Section>

        <Section>
          <ValueRow title="Version" value={version} />
        </Section>
      </List>
    </Host>
  );
}

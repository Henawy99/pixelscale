import { useEffect, useState } from 'react';
import { Alert } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, Form, HStack, Link, ProgressView, SecureField, Section, Spacer, Text, TextField } from '@expo/ui/swift-ui';
import {
  autocorrectionDisabled,
  disabled,
  keyboardType,
  scrollDismissesKeyboard,
  textContentType,
  textInputAutocapitalization,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { getGmailConfig, saveGmailConfig, testImapConnection } from '@/api/client';
import { ACCENT, text } from '@/components/theme';
import { useField } from '@/components/use-field';

const GMAIL_HOST = 'imap.gmail.com';

export default function GmailSettingsScreen() {
  const router = useRouter();
  const { refresh } = useAppData();
  const email = useField('frankbuchmann831@gmail.com');
  const password = useField('');
  const [host, setHost] = useState(GMAIL_HOST);
  const [testing, setTesting] = useState(false);

  useEffect(() => {
    getGmailConfig().then((cfg) => {
      if (cfg?.email) email.set(cfg.email);
      if (cfg?.password) password.set(cfg.password);
      if (cfg?.host) setHost(cfg.host);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const config = () => ({
    email: email.current().trim(),
    password: password.current().trim() || undefined,
    host: host || GMAIL_HOST,
    port: 993,
  });

  const save = async () => {
    if (email.current().trim()) await saveGmailConfig(config());
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    refresh();
    router.back();
  };

  const test = async () => {
    if (!email.current().trim() || !password.current().trim()) {
      Alert.alert('Missing Details', 'Enter your Gmail address and the 16-character app password.');
      return;
    }
    setTesting(true);
    try {
      await saveGmailConfig(config());
      const res = await testImapConnection({ provider: 'gmail', ...config() });
      Alert.alert(res.success ? 'Gmail Connected' : 'Gmail Connection', res.message);
    } catch (err) {
      Alert.alert('Test Failed', err instanceof Error ? err.message : 'Connection failed');
    } finally {
      setTesting(false);
    }
  };

  return (
    <>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button variant="done" tintColor={ACCENT} onPress={save}>
          Save
        </Stack.Toolbar.Button>
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <Form modifiers={[scrollDismissesKeyboard('interactively')]}>
          <Section title="Account" footer={<Text>Airbnb confirmation emails in this inbox become booking cards.</Text>}>
            <TextField
              text={email.state}
              onTextChange={email.onTextChange}
              placeholder="you@gmail.com"
              modifiers={[
                keyboardType('email-address'),
                textContentType('emailAddress'),
                textInputAutocapitalization('never'),
                autocorrectionDisabled(),
              ]}
            />
            <SecureField text={password.state} onTextChange={password.onTextChange} placeholder="App password (16 letters)" />
          </Section>

          <Section title="How to Get an App Password">
            <Text modifiers={[text.subheadline, text.secondary]}>
              {'1. Open your Google Account → Security\n2. Turn on 2-Step Verification\n3. Search for “App passwords”\n4. Create one named “Review App” and paste it above'}
            </Text>
            <Link label="Open Google App Passwords" destination="https://myaccount.google.com/apppasswords" />
          </Section>

          <Section>
            <Button onPress={test} modifiers={[disabled(testing)]}>
              <HStack>
                <Text>{testing ? 'Testing…' : 'Test Connection'}</Text>
                <Spacer />
                {testing ? <ProgressView /> : null}
              </HStack>
            </Button>
          </Section>
        </Form>
      </Host>
    </>
  );
}

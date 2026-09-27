import { useEffect, useState } from 'react';
import { Alert } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, Form, HStack, ProgressView, SecureField, Section, Spacer, Text, TextField } from '@expo/ui/swift-ui';
import {
  autocorrectionDisabled,
  disabled,
  keyboardType,
  scrollDismissesKeyboard,
  textContentType,
  textInputAutocapitalization,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { getZohoConfig, saveZohoConfig, testImapConnection } from '@/api/client';
import { ACCENT } from '@/components/theme';
import { useField } from '@/components/use-field';

const ZOHO_HOST = 'imappro.zoho.eu';

export default function ZohoSettingsScreen() {
  const router = useRouter();
  const { refresh } = useAppData();
  const email = useField('');
  const password = useField('');
  const host = useField(ZOHO_HOST);
  const [testing, setTesting] = useState(false);

  useEffect(() => {
    getZohoConfig().then((cfg) => {
      if (cfg?.email) email.set(cfg.email);
      if (cfg?.password) password.set(cfg.password);
      if (cfg?.host) host.set(cfg.host);
    });
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const config = () => ({
    email: email.current().trim(),
    password: password.current().trim() || undefined,
    host: host.current().trim() || ZOHO_HOST,
    port: 993,
  });

  const save = async () => {
    if (email.current().trim()) await saveZohoConfig(config());
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    refresh();
    router.back();
  };

  const test = async () => {
    if (!email.current().trim()) {
      Alert.alert('Missing Email', 'Enter your Zoho email address.');
      return;
    }
    setTesting(true);
    try {
      const res = await testImapConnection({ provider: 'zoho', ...config() });
      Alert.alert(res.success ? 'Zoho Connected' : 'Zoho Connection', res.message);
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
          <Section
            title="Account"
            footer={<Text>The server already has default Zoho credentials. Only fill this in to use a different inbox.</Text>}>
            <TextField
              text={email.state}
              onTextChange={email.onTextChange}
              placeholder="bookings@yourdomain.com"
              modifiers={[
                keyboardType('email-address'),
                textContentType('emailAddress'),
                textInputAutocapitalization('never'),
                autocorrectionDisabled(),
              ]}
            />
            <SecureField text={password.state} onTextChange={password.onTextChange} placeholder="App-specific password" />
          </Section>

          <Section title="IMAP Host">
            <TextField
              text={host.state}
              onTextChange={host.onTextChange}
              placeholder={ZOHO_HOST}
              modifiers={[keyboardType('url'), textInputAutocapitalization('never'), autocorrectionDisabled()]}
            />
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

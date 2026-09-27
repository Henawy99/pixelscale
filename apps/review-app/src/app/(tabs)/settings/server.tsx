import { useEffect } from 'react';
import { Stack, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import { Button, Form, SecureField, Section, Text, TextField } from '@expo/ui/swift-ui';
import {
  autocorrectionDisabled,
  keyboardType,
  scrollDismissesKeyboard,
  textInputAutocapitalization,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { DEFAULT_API_URL, getApiBaseUrl, getGeminiKey, saveGeminiKey, setApiBaseUrl } from '@/api/client';
import { ACCENT } from '@/components/theme';
import { useField } from '@/components/use-field';

export default function ServerSettingsScreen() {
  const router = useRouter();
  const { refresh } = useAppData();
  const apiUrl = useField(DEFAULT_API_URL);
  const geminiKey = useField('');

  useEffect(() => {
    getApiBaseUrl().then(apiUrl.set);
    getGeminiKey().then(geminiKey.set);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const save = async () => {
    await setApiBaseUrl(apiUrl.current().trim() || DEFAULT_API_URL);
    await saveGeminiKey(geminiKey.current());
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    refresh();
    router.back();
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
          <Section title="API Server" footer={<Text>The Vercel backend that reads the inboxes and runs Gemini.</Text>}>
            <TextField
              text={apiUrl.state}
              onTextChange={apiUrl.onTextChange}
              placeholder={DEFAULT_API_URL}
              modifiers={[keyboardType('url'), textInputAutocapitalization('never'), autocorrectionDisabled()]}
            />
            {apiUrl.value.trim() !== DEFAULT_API_URL ? (
              <Button label="Reset to Default" systemImage="arrow.uturn.backward" onPress={() => apiUrl.set(DEFAULT_API_URL)} />
            ) : null}
          </Section>

          <Section
            title="Gemini API Key"
            footer={<Text>Optional. Leave empty to use the server’s key, or add your own to use your own quota.</Text>}>
            <SecureField text={geminiKey.state} onTextChange={geminiKey.onTextChange} placeholder="AIzaSy…" />
          </Section>
        </Form>
      </Host>
    </>
  );
}

import { useState } from 'react';
import { Alert, Pressable, ScrollView, Share } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Image as ExpoImage } from 'expo-image';
import * as Clipboard from 'expo-clipboard';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import {
  Button,
  ContentUnavailableView,
  HStack,
  Image,
  List,
  RNHostView,
  Section,
  Text,
  VStack,
} from '@expo/ui/swift-ui';
import {
  foregroundStyle,
  listStyle,
  textSelection,
} from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { formatRelative } from '@/lib/dates';
import { ACCENT, text } from '@/components/theme';

export default function HistoryItemScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const router = useRouter();
  const { history, deleteHistory } = useAppData();
  const item = history.find((h) => h.id === id);
  const [copied, setCopied] = useState(false);

  if (!item) {
    return (
      <Host style={{ flex: 1 }}>
        <ContentUnavailableView title="Review Not Found" systemImage="star.slash" />
      </Host>
    );
  }

  const { review, tour, photos = [] } = item;
  const fullText = review.headline ? `${review.headline}\n\n${review.text}` : review.text;

  const copy = async () => {
    await Clipboard.setStringAsync(review.text);
    Haptics.notificationAsync(Haptics.NotificationFeedbackType.Success);
    setCopied(true);
    setTimeout(() => setCopied(false), 1500);
  };

  const remove = () =>
    Alert.alert('Delete Review?', 'It is removed from your history.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          await deleteHistory(item.id);
          router.back();
        },
      },
    ]);

  return (
    <>
      <Stack.Screen options={{ title: formatRelative(item.timestamp) }} />
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button icon="square.and.arrow.up" onPress={() => Share.share({ message: fullText })} accessibilityLabel="Share" />
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List modifiers={[listStyle('insetGrouped')]}>
          <Section title={tour?.title || 'Tour'}>
            <VStack alignment="leading" spacing={8}>
              <HStack spacing={2}>
                {[0, 1, 2, 3, 4].map((i) => (
                  <Image key={i} systemName="star.fill" size={14} color="#F5A524" />
                ))}
                <Text modifiers={[text.footnote, text.secondary]}>{`  ${review.tone}`}</Text>
              </HStack>
              {review.headline ? <Text modifiers={[text.headline]}>{review.headline}</Text> : null}
              <Text modifiers={[text.body, textSelection(true)]}>{review.text}</Text>
            </VStack>
          </Section>

          {photos.length > 0 ? (
            <Section title={`Photos · ${photos.length}`}>
              <RNHostView matchContents>
                <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ gap: 10, paddingHorizontal: 16 }} style={{ height: 120, marginHorizontal: -16 }}>
                  {photos.map((p, i) => (
                    <Pressable
                      key={p.id || i}
                      onPress={() => router.push({ pathname: '/photo', params: { uri: p.url || p.thumbUrl, credit: `${p.source} · ${p.photographer}` } })}>
                      <ExpoImage
                        source={{ uri: p.thumbUrl || p.url }}
                        style={{ width: 160, height: 120, borderRadius: 10 }}
                        contentFit="cover"
                        transition={200}
                      />
                    </Pressable>
                  ))}
                </ScrollView>
              </RNHostView>
            </Section>
          ) : null}

          <Section>
            <Button label={copied ? 'Copied' : 'Copy Review'} systemImage={copied ? 'checkmark' : 'doc.on.doc'} onPress={copy} />
            <Button
              label="Write Another for This Tour"
              systemImage="sparkles"
              onPress={() =>
                router.push({ pathname: '/studio', params: { url: tour?.originalUrl || tour?.title || '', notes: tour?.title ?? '' } })
              }
            />
          </Section>

          <Section>
            <Button role="destructive" label="Delete Review" systemImage="trash" onPress={remove} modifiers={[foregroundStyle('red')]} />
          </Section>
        </List>
      </Host>
    </>
  );
}

import { Alert } from 'react-native';
import { Stack, useRouter } from 'expo-router';
import * as Haptics from 'expo-haptics';
import { Host } from '@expo/ui';
import {
  Button,
  ContentUnavailableView,
  HStack,
  Image,
  List,
  Section,
  Spacer,
  SwipeActions,
  Text,
  VStack,
} from '@expo/ui/swift-ui';
import { listStyle, tint } from '@expo/ui/swift-ui/modifiers';
import { useAppData } from '@/state/app-data';
import { HistoryItem } from '@/types';
import { formatRelative } from '@/lib/dates';
import { ACCENT, text } from '@/components/theme';

export default function ReviewsScreen() {
  const router = useRouter();
  const { history, deleteHistory } = useAppData();

  const confirmDelete = (item: HistoryItem) =>
    Alert.alert('Delete Review?', 'It is removed from your history. Reviews already attached to bookings are kept.', [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Delete',
        style: 'destructive',
        onPress: async () => {
          Haptics.notificationAsync(Haptics.NotificationFeedbackType.Warning);
          await deleteHistory(item.id);
        },
      },
    ]);

  return (
    <>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button icon="square.and.pencil" onPress={() => router.push('/studio')} accessibilityLabel="New review" />
      </Stack.Toolbar>

      <Host style={{ flex: 1 }} seedColor={ACCENT}>
        <List modifiers={[listStyle('insetGrouped')]}>
          <Section footer={<Text>Generates a 5★ traveler review and matching photos for any tour.</Text>}>
            <Button label="Write a New Review" systemImage="sparkles" onPress={() => router.push('/studio')} />
          </Section>

          <Section title={`Generated · ${history.length}`}>
            {history.length === 0 ? (
              <ContentUnavailableView
                title="No Reviews Yet"
                systemImage="star.bubble"
                description="Reviews you generate show up here so you can copy or reuse them."
              />
            ) : (
              history.map((item) => (
                <SwipeActions key={item.id}>
                  <Button onPress={() => router.push(`/reviews/history/${item.id}`)}>
                    <HStack spacing={12}>
                      <VStack alignment="leading" spacing={3}>
                        <Text modifiers={[text.rowTitle, text.oneLine, text.primary]}>
                          {item.review?.headline || item.tour?.title || 'Tour review'}
                        </Text>
                        <Text modifiers={[text.footnote, text.twoLines, text.secondary]}>{item.review?.text ?? ''}</Text>
                        <Text modifiers={[text.caption, text.tertiary]}>
                          {[
                            formatRelative(item.timestamp),
                            item.tour?.title,
                            item.photos?.length ? `${item.photos.length} photos` : null,
                          ]
                            .filter(Boolean)
                            .join(' · ')}
                        </Text>
                      </VStack>
                      <Spacer />
                      <Image systemName="chevron.right" size={12} color="#C7C7CC" />
                    </HStack>
                  </Button>
                  <SwipeActions.Actions edge="trailing">
                    <Button label="Delete" systemImage="trash" onPress={() => confirmDelete(item)} modifiers={[tint('red')]} />
                  </SwipeActions.Actions>
                </SwipeActions>
              ))
            )}
          </Section>
        </List>
      </Host>
    </>
  );
}

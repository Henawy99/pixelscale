import { Share, Text, View } from 'react-native';
import { Stack, useLocalSearchParams, useRouter } from 'expo-router';
import { Image } from 'expo-image';

export default function PhotoScreen() {
  const { uri, credit } = useLocalSearchParams<{ uri: string; credit?: string }>();
  const router = useRouter();

  return (
    <>
      <Stack.Toolbar placement="left">
        <Stack.Toolbar.Button icon="xmark" onPress={() => router.back()} accessibilityLabel="Close" />
      </Stack.Toolbar>
      <Stack.Toolbar placement="right">
        <Stack.Toolbar.Button icon="square.and.arrow.up" onPress={() => Share.share({ url: uri })} accessibilityLabel="Share" />
      </Stack.Toolbar>
      <View style={{ flex: 1, backgroundColor: 'black', justifyContent: 'center' }}>
        <Image source={{ uri }} style={{ flex: 1 }} contentFit="contain" transition={200} />
        {credit ? (
          <Text selectable style={{ color: '#ffffffaa', textAlign: 'center', padding: 16, fontSize: 13 }}>
            {credit}
          </Text>
        ) : null}
      </View>
    </>
  );
}

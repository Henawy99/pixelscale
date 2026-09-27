import { Share } from 'react-native';
import { requireOptionalNativeModule } from 'expo';

interface ShareSheetNativeModule {
  shareAsync(fileUrls: string[], message: string | null): Promise<boolean>;
}

// The local module in modules/share-sheet. It is missing in Expo Go and in builds made before it was added.
const ShareSheet = requireOptionalNativeModule<ShareSheetNativeModule>('ShareSheet');

/** False in Expo Go and older builds, where only the first file can be shared. */
export const canShareSeveralFiles = ShareSheet !== null;

/**
 * Opens the iOS share sheet with every file and the message together.
 * Resolves `true` when something was shared, `false` when the sheet was closed.
 */
export async function shareFiles(fileUrls: string[], message?: string): Promise<boolean> {
  if (ShareSheet) return ShareSheet.shareAsync(fileUrls, message?.trim() || null);
  const result = await Share.share({ url: fileUrls[0], message });
  return result.action === Share.sharedAction;
}

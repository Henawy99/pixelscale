import { Alert, Linking } from 'react-native';
import { BookingItem } from '../types';

export async function openUrl(url: string) {
  try {
    await Linking.openURL(url);
  } catch {
    Alert.alert('Can’t open link', url);
  }
}

export function callPhone(phone: string) {
  return openUrl(`tel:${phone.replace(/\s+/g, '')}`);
}

export function mapsUrlFor(b: BookingItem): string | null {
  if (b.mapsUrl) return b.mapsUrl;
  if (b.pickup) return `https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(b.pickup)}`;
  return null;
}

export function openPickup(b: BookingItem) {
  const url = mapsUrlFor(b);
  if (url) return openUrl(url);
}

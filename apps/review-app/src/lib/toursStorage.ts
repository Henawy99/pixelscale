import AsyncStorage from '@react-native-async-storage/async-storage';
import { OfferedTour } from '../types';

export const STORAGE_KEY_OFFERED_TOURS = '@pixelreview_offered_tours';

export const DEFAULT_OFFERED_TOURS: OfferedTour[] = [
  {
    id: 'tour_hallstatt_salt_mine',
    title: 'From Salzburg: Hallstatt Salt Mine & Skywalk Private Tour',
    gygUrl: 'https://www.getyourguide.com/salzburg-l4/from-salzburg-hallstatt-salt-mine-skywalk-private-tour-t458392/',
    location: 'Salzburg / Hallstatt',
    ticketCostPerPassenger: 49,
    notes: 'Includes funicular & salt mine entry tickets. 8-hour private day trip.',
    createdAt: Date.now() - 86400000 * 14,
  },
  {
    id: 'tour_salzburg_eagles_nest',
    title: 'From Salzburg: Eagle\'s Nest & Berchtesgaden Private Tour',
    gygUrl: 'https://www.getyourguide.com/salzburg-l4/from-salzburg-eagle-s-nest-and-bavarian-alps-private-tour-t412850/',
    location: 'Salzburg / Bavaria',
    ticketCostPerPassenger: 32,
    notes: 'Historic alpine tour through Bavarian Alps & Obersalzberg.',
    createdAt: Date.now() - 86400000 * 10,
  },
  {
    id: 'tour_sound_of_music',
    title: 'Salzburg: Original Sound of Music Locations Private Tour',
    gygUrl: 'https://www.getyourguide.com/salzburg-l4/original-sound-of-music-tour-salzburg-t3821/',
    location: 'Salzburg',
    ticketCostPerPassenger: 0,
    notes: 'Leopoldskron, Hellbrunn Palace, Mirabell Gardens & Salzkammergut.',
    createdAt: Date.now() - 86400000 * 7,
  },
];

/**
 * Extracts a readable tour title from a GetYourGuide URL slug
 * e.g. https://www.getyourguide.com/salzburg-l4/from-salzburg-hallstatt-salt-mine-skywalk-private-tour-t458392/
 * -> "From Salzburg Hallstatt Salt Mine Skywalk Private Tour"
 */
export function extractTitleFromGygUrl(url: string): { title: string; location?: string } {
  try {
    const clean = url.trim().replace(/\/$/, '');
    const parts = clean.split('/');
    const lastSlug = parts[parts.length - 1] || '';

    // Remove tour id at the end like "-t458392"
    const slugWithoutId = lastSlug.replace(/-t\d+.*$/, '');

    // Format title case
    const title = slugWithoutId
      .split('-')
      .filter(Boolean)
      .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
      .join(' ');

    // Try extracting location from the preceding slug part (e.g. "salzburg-l4")
    let location: string | undefined;
    if (parts.length >= 2) {
      const locPart = parts[parts.length - 2];
      if (locPart && locPart.includes('-l')) {
        location = locPart
          .replace(/-l\d+.*$/, '')
          .split('-')
          .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
          .join(' ');
      }
    }

    return {
      title: title || 'GetYourGuide Tour',
      location,
    };
  } catch {
    return { title: 'GetYourGuide Tour' };
  }
}

/**
 * Retrieve all offered tours from AsyncStorage
 */
export async function getStoredOfferedTours(): Promise<OfferedTour[]> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY_OFFERED_TOURS);
    if (!raw) {
      await AsyncStorage.setItem(
        STORAGE_KEY_OFFERED_TOURS,
        JSON.stringify(DEFAULT_OFFERED_TOURS)
      );
      return DEFAULT_OFFERED_TOURS;
    }
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : DEFAULT_OFFERED_TOURS;
  } catch (err) {
    console.warn('Error reading offered tours:', err);
    return DEFAULT_OFFERED_TOURS;
  }
}

/**
 * Save or update an offered tour
 */
export async function saveOfferedTour(tour: OfferedTour): Promise<OfferedTour[]> {
  const current = await getStoredOfferedTours();
  const index = current.findIndex((t) => t.id === tour.id);
  let updated: OfferedTour[];
  if (index >= 0) {
    updated = [...current];
    updated[index] = tour;
  } else {
    updated = [tour, ...current];
  }
  await AsyncStorage.setItem(STORAGE_KEY_OFFERED_TOURS, JSON.stringify(updated));
  return updated;
}

/**
 * Delete an offered tour
 */
export async function deleteOfferedTour(id: string): Promise<OfferedTour[]> {
  const current = await getStoredOfferedTours();
  const updated = current.filter((t) => t.id !== id);
  await AsyncStorage.setItem(STORAGE_KEY_OFFERED_TOURS, JSON.stringify(updated));
  return updated;
}

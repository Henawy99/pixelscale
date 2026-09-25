import AsyncStorage from '@react-native-async-storage/async-storage';
import { Linking, Alert, Share } from 'react-native';
import { Reviewer, ReviewerAssignment, BookingItem } from '../types';

export const STORAGE_KEY_REVIEWERS = '@pixelreview_reviewers';
export const STORAGE_KEY_REVIEWER_ASSIGNMENTS = '@pixelreview_reviewer_assignments';

export const DEFAULT_REVIEWERS: Reviewer[] = [
  {
    id: 'rev_1',
    name: 'Sophie Lindner',
    phone: '+43 664 1234567',
    color: '#ec4899',
    notes: 'Local Salzburg reviewer, English & German',
    createdAt: Date.now() - 86400000 * 5,
  },
  {
    id: 'rev_2',
    name: 'Marco Rossi',
    phone: '+43 660 7654321',
    color: '#06b6d4',
    notes: 'Italian & English speaker, mountain photography enthusiast',
    createdAt: Date.now() - 86400000 * 3,
  },
];

/**
 * Retrieve all reviewers from AsyncStorage
 */
export async function getStoredReviewers(): Promise<Reviewer[]> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY_REVIEWERS);
    if (!raw) {
      await AsyncStorage.setItem(
        STORAGE_KEY_REVIEWERS,
        JSON.stringify(DEFAULT_REVIEWERS)
      );
      return DEFAULT_REVIEWERS;
    }
    const parsed = JSON.parse(raw);
    return Array.isArray(parsed) ? parsed : DEFAULT_REVIEWERS;
  } catch (err) {
    console.warn('Error reading reviewers:', err);
    return DEFAULT_REVIEWERS;
  }
}

/**
 * Save or update a reviewer
 */
export async function saveReviewer(reviewer: Reviewer): Promise<Reviewer[]> {
  const current = await getStoredReviewers();
  const index = current.findIndex((r) => r.id === reviewer.id);
  let updated: Reviewer[];
  if (index >= 0) {
    updated = [...current];
    updated[index] = reviewer;
  } else {
    updated = [reviewer, ...current];
  }
  await AsyncStorage.setItem(STORAGE_KEY_REVIEWERS, JSON.stringify(updated));
  return updated;
}

/**
 * Delete a reviewer and clean up their assignments
 */
export async function deleteReviewer(id: string): Promise<Reviewer[]> {
  const current = await getStoredReviewers();
  const updated = current.filter((r) => r.id !== id);
  await AsyncStorage.setItem(STORAGE_KEY_REVIEWERS, JSON.stringify(updated));

  // Also clean up any assignments to this reviewer
  try {
    const assignments = await getStoredReviewerAssignments();
    let hasChanges = false;
    const updatedAssignments: Record<string, ReviewerAssignment> = {};
    for (const [ref, assign] of Object.entries(assignments)) {
      if (assign.reviewerId === id) {
        hasChanges = true;
      } else {
        updatedAssignments[ref] = assign;
      }
    }
    if (hasChanges) {
      await AsyncStorage.setItem(
        STORAGE_KEY_REVIEWER_ASSIGNMENTS,
        JSON.stringify(updatedAssignments)
      );
    }
  } catch {
    // Ignore cleanup error
  }

  return updated;
}

/**
 * Retrieve all reviewer assignments mapped by booking reference number
 */
export async function getStoredReviewerAssignments(): Promise<Record<string, ReviewerAssignment>> {
  try {
    const raw = await AsyncStorage.getItem(STORAGE_KEY_REVIEWER_ASSIGNMENTS);
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return typeof parsed === 'object' && parsed !== null ? parsed : {};
  } catch (err) {
    console.warn('Error reading reviewer assignments:', err);
    return {};
  }
}

/**
 * Assign a reviewer and optional review text / photos to a booking
 */
export async function assignReviewerToBooking(
  bookingRef: string,
  reviewerId: string,
  reviewText?: string,
  photoUrls?: string[],
  notes?: string
): Promise<Record<string, ReviewerAssignment>> {
  const assignments = await getStoredReviewerAssignments();
  const existing = assignments[bookingRef];

  assignments[bookingRef] = {
    bookingRef,
    reviewerId,
    assignedAt: Date.now(),
    reviewText: reviewText ?? existing?.reviewText,
    photoUrls: photoUrls ?? existing?.photoUrls ?? [],
    notes: notes ?? existing?.notes,
  };

  await AsyncStorage.setItem(
    STORAGE_KEY_REVIEWER_ASSIGNMENTS,
    JSON.stringify(assignments)
  );
  return assignments;
}

/**
 * Remove reviewer assignment from a booking
 */
export async function unassignReviewerFromBooking(
  bookingRef: string
): Promise<Record<string, ReviewerAssignment>> {
  const assignments = await getStoredReviewerAssignments();
  if (assignments[bookingRef]) {
    delete assignments[bookingRef];
    await AsyncStorage.setItem(
      STORAGE_KEY_REVIEWER_ASSIGNMENTS,
      JSON.stringify(assignments)
    );
  }
  return assignments;
}

/**
 * Formats a clean, professional WhatsApp message with review text and photo links
 */
export function formatWhatsAppReviewMessage(
  booking: BookingItem,
  reviewerName?: string,
  reviewText?: string,
  photoUrls?: string[]
): string {
  const greeting = reviewerName ? `Hi ${reviewerName.trim()}! 👋` : 'Hi! 👋';
  const tourName = booking.tourTitle || 'Your GetYourGuide Tour';

  let msg = `${greeting}\nHere is the review for booking ${booking.referenceNumber} (${tourName}):\n\n`;
  msg += `⭐⭐⭐⭐⭐\n`;

  if (reviewText && reviewText.trim()) {
    msg += `"${reviewText.trim()}"\n\n`;
  } else {
    msg += `"An absolute highlight of our trip! Seamless service, beautiful sights, and highly recommended to all travelers visiting Austria."\n\n`;
  }

  if (photoUrls && photoUrls.length > 0) {
    msg += `📸 Recommended Photos:\n`;
    photoUrls.forEach((url, index) => {
      msg += `Photo ${index + 1}: ${url}\n`;
    });
    msg += `\n`;
  }

  msg += `Please submit the review on GetYourGuide whenever you have a moment. Thank you so much! 🙏`;
  return msg;
}

/**
 * Opens WhatsApp directly with the reviewer's phone number and pre-filled message,
 * with fallback to the web URL and system share sheet.
 */
export async function shareToWhatsApp(
  phone: string | undefined,
  messageText: string
): Promise<void> {
  // Clean phone number: remove non-digits except leading +
  const cleanPhone = (phone || '').replace(/[^\d+]/g, '').replace(/^\+/, '');

  const encodedText = encodeURIComponent(messageText);

  // If phone number is available, target directly via whatsapp:// or https://wa.me/
  if (cleanPhone.length >= 7) {
    const whatsappAppUrl = `whatsapp://send?phone=${cleanPhone}&text=${encodedText}`;
    const whatsappWebUrl = `https://wa.me/${cleanPhone}?text=${encodedText}`;

    try {
      const canOpen = await Linking.canOpenURL(whatsappAppUrl);
      if (canOpen) {
        await Linking.openURL(whatsappAppUrl);
        return;
      } else {
        await Linking.openURL(whatsappWebUrl);
        return;
      }
    } catch {
      // Fallback to web link
      await Linking.openURL(whatsappWebUrl);
      return;
    }
  }

  // If no phone number was set for this reviewer, open WhatsApp contact picker or system share
  const generalWhatsappUrl = `whatsapp://send?text=${encodedText}`;
  try {
    const canOpen = await Linking.canOpenURL(generalWhatsappUrl);
    if (canOpen) {
      await Linking.openURL(generalWhatsappUrl);
      return;
    }
  } catch {
    // Fall back to system share sheet
  }

  // System Share Sheet Fallback
  try {
    await Share.share({
      message: messageText,
      title: 'GetYourGuide Review & Photos',
    });
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : 'Unable to share';
    Alert.alert('Share Failed', msg);
  }
}

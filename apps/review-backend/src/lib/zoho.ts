import { ImapFlow } from 'imapflow';
import { simpleParser } from 'mailparser';
import { BookingItem, ZohoConfig } from './types';
import { parseGetYourGuideBooking } from './gygParser';
import { SAMPLE_BOOKINGS } from './sampleBookings';

export { SAMPLE_BOOKINGS };

/**
 * Fetch bookings from Zoho Mail IMAP.
 */
// In-memory cache for fast UI responsiveness
let memoryCache: {
  bookings: BookingItem[];
  timestamp: number;
  source: 'zoho' | 'mock';
  error?: string;
} | null = null;

const CACHE_TTL_MS = 60 * 1000; // 60 seconds

let activeFetchPromise: Promise<{
  bookings: BookingItem[];
  source: 'zoho' | 'mock';
  error?: string;
}> | null = null;

/**
 * Fetch bookings from Zoho Mail IMAP.
 */
export async function fetchZohoBookings(config?: Partial<ZohoConfig>): Promise<{
  bookings: BookingItem[];
  source: 'zoho' | 'mock';
  error?: string;
}> {
  const email = config?.email || process.env.ZOHO_EMAIL;
  const password = config?.password || process.env.ZOHO_PASSWORD || process.env.ZOHO_APP_PASSWORD;
  const defaultHost = email && email.toLowerCase().includes('@gmail.com') ? 'imap.gmail.com' : 'imappro.zoho.eu';
  const host = process.env.ZOHO_IMAP_HOST || (config?.host && config.host !== 'imap.zoho.eu' ? config.host : defaultHost);
  const port = Number(process.env.ZOHO_IMAP_PORT || config?.port || 993);
  const folder = config?.folder || process.env.ZOHO_FOLDER || 'INBOX';
  const forceRefresh = !!config?.forceRefresh;

  // Return from in-memory cache if fresh and not force-refreshed
  if (!forceRefresh && memoryCache && Date.now() - memoryCache.timestamp < CACHE_TTL_MS) {
    return {
      bookings: memoryCache.bookings,
      source: memoryCache.source,
      error: memoryCache.error,
    };
  }

  if (!email || !password) {
    return {
      bookings: [],
      source: 'mock',
      error: 'Zoho credentials not configured',
    };
  }

  // If another fetch is already executing, reuse it to avoid concurrent IMAP connection limits
  if (activeFetchPromise) {
    return activeFetchPromise;
  }

  activeFetchPromise = (async () => {
    const client = new ImapFlow({
      host,
      port,
      secure: port === 993,
      auth: {
        user: email,
        pass: password,
      },
      logger: false,
      socketTimeout: 30000,
      clientInfo: {
        name: 'PixelReview App',
        version: '1.0.0',
      },
    });

    try {
      await client.connect();

      // Zoho routes GetYourGuide automated booking emails to "Notification",
      // while customer inquiries land in "INBOX". We scan both to get all historical bookings.
      const foldersToScan = ['Notification', folder || 'INBOX'];
      const parsedBookings: BookingItem[] = [];

      for (const currentFolder of foldersToScan) {
        try {
          const lock = await client.getMailboxLock(currentFolder);
          try {
            let searchUids: number[] = [];
            try {
              const uids = await client.search(
                {
                  or: [
                    { from: 'getyourguide' },
                    { subject: 'booking' },
                    { subject: 'cancelled' },
                    { subject: 'canceled' },
                    { body: 'GetYourGuide' },
                    { body: 'GYG' },
                    { body: 'cancelled' },
                    { body: 'canceled' },
                  ],
                },
                { uid: true }
              );
              if (Array.isArray(uids)) {
                searchUids = uids;
              }
            } catch {
              const allUids = await client.search({ all: true }, { uid: true });
              if (Array.isArray(allUids)) {
                searchUids = allUids;
              }
            }

            // Sort descending (newest first) and take up to 500 messages to cover full history
            const recentUids = searchUids.reverse().slice(0, 500);

            if (recentUids.length > 0) {
              // Pre-filter with envelopes to download bodies only for relevant emails
              const candidateUids: number[] = [];
              for await (const msg of client.fetch(recentUids, {
                envelope: true,
                uid: true,
              })) {
                const subj = (msg.envelope?.subject || '').toLowerCase();
                const isExcluded =
                  subj.includes('we value your feedback') ||
                  subj.includes('ticket id') ||
                  subj.includes('product was not accepted') ||
                  subj.includes('product is approved') ||
                  subj.includes('fix these quality issues') ||
                  subj.includes('password') ||
                  subj.includes('verification code') ||
                  subj.includes('musement') ||
                  subj.includes('headout') ||
                  subj.includes('welcome aboard') ||
                  subj.includes('zoho workplace') ||
                  subj.includes('invoice');

                if (!isExcluded) {
                  candidateUids.push(msg.uid);
                }
              }

              if (candidateUids.length > 0) {
                for await (const message of client.fetch(candidateUids, {
                  source: true,
                  envelope: true,
                  uid: true,
                  internalDate: true,
                })) {
                  try {
                    if (!message || !message.source) continue;

                    const parsedEmail = await simpleParser(message.source);
                    const booking = parseGetYourGuideBooking({
                      subject: parsedEmail.subject || message.envelope?.subject,
                      text: parsedEmail.text,
                      html: parsedEmail.html ? String(parsedEmail.html) : undefined,
                      date: message.internalDate || parsedEmail.date,
                      messageId: parsedEmail.messageId,
                    });

                if (booking) {
                  const existingIndex = parsedBookings.findIndex(
                    (b) => b.referenceNumber === booking.referenceNumber
                  );

                  if (existingIndex >= 0) {
                    const existing = parsedBookings[existingIndex];
                    const isCancelled =
                      booking.status === 'cancelled' || existing.status === 'cancelled';
                    parsedBookings[existingIndex] = {
                      ...existing,
                      tourTitle:
                        booking.tourTitle &&
                        booking.tourTitle !== 'GetYourGuide Experience' &&
                        (!existing.tourTitle || existing.tourTitle === 'GetYourGuide Experience')
                          ? booking.tourTitle
                          : existing.tourTitle,
                      fareOption: booking.fareOption || existing.fareOption,
                      customerName:
                        booking.customerName &&
                        booking.customerName !== 'GetYourGuide Customer' &&
                        (!existing.customerName || existing.customerName === 'GetYourGuide Customer')
                          ? booking.customerName
                          : existing.customerName,
                      customerEmail: booking.customerEmail || existing.customerEmail,
                      customerPhone: booking.customerPhone || existing.customerPhone,
                      pickup:
                        booking.pickup &&
                        booking.pickup !== 'As arranged with provider' &&
                        (!existing.pickup || existing.pickup === 'As arranged with provider')
                          ? booking.pickup
                          : existing.pickup,
                      mapsUrl: booking.mapsUrl || existing.mapsUrl,
                      bookingUrl: booking.bookingUrl || existing.bookingUrl,
                      imageUrl: booking.imageUrl || existing.imageUrl,
                      price:
                        booking.price && booking.price !== 'Paid'
                          ? booking.price
                          : existing.price,
                      priceAmount:
                        typeof booking.priceAmount === 'number'
                          ? booking.priceAmount
                          : existing.priceAmount,
                      isReviewBooking:
                        typeof booking.isReviewBooking === 'boolean'
                          ? booking.isReviewBooking
                          : existing.isReviewBooking,
                      isLastMinute: booking.isLastMinute || existing.isLastMinute,
                      status: isCancelled
                        ? 'cancelled'
                        : booking.isLastMinute || existing.isLastMinute
                        ? 'last-minute'
                        : 'confirmed',
                    };
                  } else {
                    parsedBookings.push(booking);
                  }
                }
              } catch (fetchErr) {
                console.warn(`Error parsing email:`, fetchErr);
              }
            }
          }
        }
      } finally {
        lock.release();
      }
      } catch (folderErr) {
        console.warn(`Folder ${currentFolder} scan notice:`, folderErr);
      }
    }

    await client.logout();

    // Return only real parsed bookings from Zoho
    const finalBookings = [...parsedBookings];

    // Sort by timestamp descending
    finalBookings.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));

    // Store in memory cache
    memoryCache = {
      bookings: finalBookings,
      timestamp: Date.now(),
      source: 'zoho',
    };

    return {
      bookings: finalBookings,
      source: 'zoho',
    };
    } catch (err: unknown) {
      const errorObj = err as { message?: string; responseText?: string; response?: string };
      const rawError = errorObj?.responseText || errorObj?.message || String(err);
      console.error('Zoho IMAP Error:', rawError);

      let hint = 'Check your Zoho app password and IMAP server.';
      if (rawError.toLowerCase().includes('yet to enable') || rawError.toLowerCase().includes('enable imap')) {
        hint = 'IMAP access is currently turned OFF in your Zoho account. Log in to mail.zoho.eu → Settings → Mail Accounts → Enable IMAP Access.';
      }

      return {
        bookings: [],
        source: 'mock',
        error: `Zoho IMAP: ${rawError}. ${hint}`,
      };
    } finally {
      activeFetchPromise = null;
    }
  })();

  return activeFetchPromise;
}

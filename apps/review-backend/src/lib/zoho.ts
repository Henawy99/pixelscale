import { ImapFlow } from 'imapflow';
import { simpleParser } from 'mailparser';
import { BookingItem, ZohoConfig, GmailConfig } from './types';
import { parseGetYourGuideBooking } from './gygParser';
import { parseAirbnbBooking, isAirbnbEmail } from './airbnbParser';
import { SAMPLE_BOOKINGS } from './sampleBookings';

export { SAMPLE_BOOKINGS };

// In-memory cache for fast UI responsiveness
let memoryCache: {
  bookings: BookingItem[];
  timestamp: number;
  source: 'zoho' | 'gmail' | 'multi' | 'mock';
  error?: string;
  zohoStatus?: string;
  gmailStatus?: string;
} | null = null;

const CACHE_TTL_MS = 60 * 1000; // 60 seconds

let activeFetchPromise: Promise<{
  bookings: BookingItem[];
  source: 'zoho' | 'gmail' | 'multi' | 'mock';
  error?: string;
  zohoStatus?: string;
  gmailStatus?: string;
}> | null = null;

export interface FetchOptions {
  zoho?: Partial<ZohoConfig>;
  gmail?: Partial<GmailConfig>;
  forceRefresh?: boolean;
}

/**
 * Universal mail fetcher that fetches and merges bookings from Zoho (GYG) and Gmail (Airbnb).
 */
export async function fetchAllBookings(options?: FetchOptions): Promise<{
  bookings: BookingItem[];
  source: 'zoho' | 'gmail' | 'multi' | 'mock';
  error?: string;
  zohoStatus?: string;
  gmailStatus?: string;
}> {
  const forceRefresh = !!options?.forceRefresh;

  // Return from in-memory cache if fresh and not force-refreshed
  if (!forceRefresh && memoryCache && Date.now() - memoryCache.timestamp < CACHE_TTL_MS) {
    return {
      bookings: memoryCache.bookings,
      source: memoryCache.source,
      error: memoryCache.error,
      zohoStatus: memoryCache.zohoStatus,
      gmailStatus: memoryCache.gmailStatus,
    };
  }

  // If another fetch is already executing, reuse it to avoid concurrent IMAP connection limits
  if (activeFetchPromise) {
    return activeFetchPromise;
  }

  activeFetchPromise = (async () => {
    // 1. Resolve Zoho Credentials
    const zohoEmail = options?.zoho?.email || process.env.ZOHO_EMAIL;
    const zohoPass = options?.zoho?.password || process.env.ZOHO_PASSWORD || process.env.ZOHO_APP_PASSWORD;
    const zohoHost = options?.zoho?.host || process.env.ZOHO_IMAP_HOST || (zohoEmail?.toLowerCase().includes('@gmail.com') ? 'imap.gmail.com' : 'imappro.zoho.eu');
    const zohoPort = Number(options?.zoho?.port || process.env.ZOHO_IMAP_PORT || 993);

    // 2. Resolve Gmail Credentials
    const gmailEmail = options?.gmail?.email || process.env.GMAIL_EMAIL;
    const gmailPass = options?.gmail?.password || process.env.GMAIL_PASSWORD || process.env.GMAIL_APP_PASSWORD;
    const gmailHost = options?.gmail?.host || process.env.GMAIL_IMAP_HOST || 'imap.gmail.com';
    const gmailPort = Number(options?.gmail?.port || process.env.GMAIL_IMAP_PORT || 993);

    const hasZoho = Boolean(zohoEmail && zohoPass);
    const hasGmail = Boolean(gmailEmail && gmailPass);

    if (!hasZoho && !hasGmail) {
      return {
        bookings: SAMPLE_BOOKINGS,
        source: 'mock' as const,
        error: 'Neither Zoho nor Gmail IMAP credentials configured.',
      };
    }

    const tasks: Promise<{
      provider: 'zoho' | 'gmail';
      bookings: BookingItem[];
      error?: string;
    }>[] = [];

    // Fetch from Zoho if configured
    if (hasZoho) {
      tasks.push(
        fetchFromImapAccount({
          provider: 'zoho',
          email: zohoEmail!,
          password: zohoPass!,
          host: zohoHost,
          port: zohoPort,
          folders: ['Notification', options?.zoho?.folder || 'INBOX'],
        })
      );
    }

    // Fetch from Gmail if configured
    if (hasGmail) {
      tasks.push(
        fetchFromImapAccount({
          provider: 'gmail',
          email: gmailEmail!,
          password: gmailPass!,
          host: gmailHost,
          port: gmailPort,
          folders: [options?.gmail?.folder || 'INBOX'],
        })
      );
    }

    const results = await Promise.allSettled(tasks);
    const mergedMap = new Map<string, BookingItem>();
    const errors: string[] = [];
    let zohoSuccess = false;
    let gmailSuccess = false;
    let zohoStatus = '';
    let gmailStatus = '';

    for (const res of results) {
      if (res.status === 'fulfilled') {
        const val = res.value;
        if (val.error) {
          errors.push(`${val.provider}: ${val.error}`);
          if (val.provider === 'zoho') zohoStatus = `Error: ${val.error}`;
          if (val.provider === 'gmail') gmailStatus = `Error: ${val.error}`;
        } else {
          if (val.provider === 'zoho') {
            zohoSuccess = true;
            zohoStatus = `Connected (${val.bookings.length} bookings)`;
          }
          if (val.provider === 'gmail') {
            gmailSuccess = true;
            gmailStatus = `Connected (${val.bookings.length} bookings)`;
          }
        }

        for (const b of val.bookings) {
          if (!mergedMap.has(b.referenceNumber)) {
            mergedMap.set(b.referenceNumber, b);
          } else {
            // Merge existing
            const existing = mergedMap.get(b.referenceNumber)!;
            mergedMap.set(b.referenceNumber, mergeBookings(existing, b));
          }
        }
      } else {
        errors.push(String(res.reason));
      }
    }

    const mergedBookings = Array.from(mergedMap.values());
    mergedBookings.sort((a, b) => (b.timestamp || 0) - (a.timestamp || 0));

    let finalSource: 'zoho' | 'gmail' | 'multi' | 'mock' = 'mock';
    if (zohoSuccess && gmailSuccess) {
      finalSource = 'multi';
    } else if (gmailSuccess) {
      finalSource = 'gmail';
    } else if (zohoSuccess) {
      finalSource = 'zoho';
    }

    const combinedError = errors.length > 0 ? errors.join('; ') : undefined;

    // If zero real bookings found and both failed, fall back to sample bookings
    const finalBookings =
      mergedBookings.length > 0
        ? mergedBookings
        : !zohoSuccess && !gmailSuccess
        ? SAMPLE_BOOKINGS
        : [];

    memoryCache = {
      bookings: finalBookings,
      timestamp: Date.now(),
      source: finalSource,
      error: combinedError,
      zohoStatus,
      gmailStatus,
    };

    return {
      bookings: finalBookings,
      source: finalSource,
      error: combinedError,
      zohoStatus,
      gmailStatus,
    };
  })().finally(() => {
    activeFetchPromise = null;
  });

  const result = await activeFetchPromise;
  return result || { bookings: SAMPLE_BOOKINGS, source: 'mock', error: 'Fetch failed' };
}

/**
 * Backward compatibility wrapper for fetchZohoBookings.
 */
export async function fetchZohoBookings(config?: Partial<ZohoConfig>): Promise<{
  bookings: BookingItem[];
  source: 'zoho' | 'mock';
  error?: string;
}> {
  const result = await fetchAllBookings({ zoho: config, forceRefresh: config?.forceRefresh });
  return {
    bookings: result.bookings,
    source: result.source === 'mock' ? 'mock' : 'zoho',
    error: result.error,
  };
}

/**
 * Helper to connect to an IMAP account and fetch/parse bookings
 */
async function fetchFromImapAccount(params: {
  provider: 'zoho' | 'gmail';
  email: string;
  password: string;
  host: string;
  port: number;
  folders: string[];
}): Promise<{
  provider: 'zoho' | 'gmail';
  bookings: BookingItem[];
  error?: string;
}> {
  const client = new ImapFlow({
    host: params.host,
    port: params.port,
    secure: params.port === 993,
    auth: {
      user: params.email,
      pass: params.password,
    },
    logger: false,
    socketTimeout: 30000,
    clientInfo: {
      name: 'PixelReview App',
      version: '1.0.0',
    },
  });

  const parsedBookings: BookingItem[] = [];

  try {
    await client.connect();

    for (const currentFolder of params.folders) {
      try {
        const lock = await client.getMailboxLock(currentFolder);
        try {
          let searchUids: number[] = [];
          try {
            if (params.provider === 'gmail') {
              const allUids = await client.search({ all: true }, { uid: true });
              if (Array.isArray(allUids)) {
                searchUids = allUids;
              }
            } else {
              const uids = await client.search(
                {
                  or: [
                    { from: 'airbnb' },
                    { from: 'getyourguide' },
                    { subject: 'airbnb' },
                    { subject: 'booking' },
                    { subject: 'حجز' },
                    { subject: 'تأكيد' },
                    { subject: 'التجربة' },
                    { subject: 'cancelled' },
                    { subject: 'canceled' },
                    { body: 'airbnb' },
                    { body: 'حجز' },
                    { body: 'التجربة' },
                    { body: 'رمز التأكيد' },
                    { body: 'Confirmation code' },
                    { body: 'GetYourGuide' },
                    { body: 'GYG' },
                  ],
                },
                { uid: true }
              );
              if (Array.isArray(uids)) {
                searchUids = uids;
              }
            }
          } catch {
            const allUids = await client.search({ all: true }, { uid: true });
            if (Array.isArray(allUids)) {
              searchUids = allUids;
            }
          }

          // Sort descending (newest first) and take up to 500 messages
          const recentUids = searchUids.reverse().slice(0, 500);

          if (recentUids.length > 0) {
            // Pre-filter with envelopes to download bodies only for relevant emails
            const candidateUids: number[] = [];
            for await (const msg of client.fetch(recentUids, { envelope: true }, { uid: true })) {
              const subj = (msg.envelope?.subject || '').toLowerCase();
              const from = (msg.envelope?.from?.[0]?.address || '').toLowerCase();

              const isExcluded =
                subj.includes('we value your feedback') ||
                subj.includes('ticket id') ||
                subj.includes('product was not accepted') ||
                subj.includes('product is approved') ||
                subj.includes('fix these quality issues') ||
                subj.includes('password') ||
                subj.includes('security code') ||
                subj.includes('verification code') ||
                subj.includes('رمز الأمان') ||
                subj.includes('رمز التحقق') ||
                subj.includes('musement') ||
                subj.includes('headout') ||
                subj.includes('welcome aboard') ||
                subj.includes('zoho workplace') ||
                subj.includes('invoice') ||
                subj.includes('حجز للإعلان') ||
                subj.includes('الموضوع:') ||
                subj.includes('لرحلتك') ||
                subj.includes('إيصال') ||
                subj.includes('تذكير') ||
                subj.includes('reminder') ||
                subj.includes('شكرًا على طلبك') ||
                subj.includes('تمت الموافقة على تجربة') ||
                subj.includes('modern & cozy') ||
                subj.includes('madinaty') ||
                subj.includes('1br') ||
                subj.includes('2br');

              const isRelevant =
                from.includes('airbnb') ||
                from.includes('getyourguide') ||
                subj.includes('airbnb') ||
                subj.includes('getyourguide') ||
                subj.includes('booking') ||
                subj.includes('حجز') ||
                subj.includes('تأكيد') ||
                subj.includes('التجربة') ||
                subj.includes('gyg') ||
                subj.includes('reservation');

              if (!isExcluded && isRelevant) {
                candidateUids.push(msg.uid);
              }
            }

            if (candidateUids.length > 0) {
              for await (const message of client.fetch(
                candidateUids,
                {
                  source: true,
                  envelope: true,
                  internalDate: true,
                },
                { uid: true }
              )) {
                try {
                  if (!message || !message.source) continue;

                  const parsedEmail = await simpleParser(message.source);
                  const emailObj = {
                    subject: parsedEmail.subject || message.envelope?.subject,
                    text: parsedEmail.text,
                    html: parsedEmail.html ? String(parsedEmail.html) : undefined,
                    date: message.internalDate || parsedEmail.date,
                    messageId: parsedEmail.messageId,
                    from: parsedEmail.from?.text || (message.envelope?.from?.[0]?.address ? `<${message.envelope.from[0].address}>` : undefined),
                  };

                  let booking: BookingItem | null = null;
                  if (isAirbnbEmail(emailObj)) {
                    booking = parseAirbnbBooking(emailObj);
                  } else {
                    booking = parseGetYourGuideBooking(emailObj);
                  }

                  if (booking) {
                    const existingIndex = parsedBookings.findIndex(
                      (b) =>
                        b.referenceNumber === booking!.referenceNumber ||
                        (b.platform === 'airbnb' &&
                          booking!.platform === 'airbnb' &&
                          b.customerName.toLowerCase() === booking!.customerName.toLowerCase() &&
                          b.customerName !== 'Airbnb Gast' &&
                          b.customerName !== 'Airbnb Guest')
                    );

                    if (existingIndex >= 0) {
                      parsedBookings[existingIndex] = mergeBookings(
                        parsedBookings[existingIndex],
                        booking
                      );
                    } else {
                      parsedBookings.push(booking);
                    }
                  }
                } catch (fetchErr) {
                  console.warn(`Error parsing ${params.provider} email:`, fetchErr);
                }
              }
            }
          }
        } finally {
          lock.release();
        }
      } catch (folderErr) {
        console.warn(`${params.provider} folder ${currentFolder} scan notice:`, folderErr);
      }
    }

    await client.logout();

    return {
      provider: params.provider,
      bookings: parsedBookings,
    };
  } catch (err: unknown) {
    const errorObj = err as { message?: string; responseText?: string; response?: string };
    const rawError = errorObj?.responseText || errorObj?.message || String(err);
    console.error(`${params.provider} IMAP Error:`, rawError);

    let hint = '';
    if (params.provider === 'gmail') {
      if (rawError.includes('AUTHENTICATIONFAILED') || rawError.includes('Invalid credentials')) {
        hint = ' For Gmail, you must use an App Password (not your main password). Go to myaccount.google.com → Security → 2-Step Verification → App passwords.';
      }
    } else {
      if (rawError.toLowerCase().includes('yet to enable') || rawError.toLowerCase().includes('enable imap')) {
        hint = ' IMAP is OFF in Zoho. Go to mail.zoho.eu → Settings → Mail Accounts → Enable IMAP Access.';
      }
    }

    return {
      provider: params.provider,
      bookings: [],
      error: `${rawError}.${hint}`,
    };
  }
}

function mergeBookings(existing: BookingItem, incoming: BookingItem): BookingItem {
  const isCancelled = incoming.status === 'cancelled' || existing.status === 'cancelled';
  return {
    ...existing,
    tourTitle:
      incoming.tourTitle &&
      incoming.tourTitle !== 'GetYourGuide Experience' &&
      incoming.tourTitle !== 'Airbnb Experience' &&
      (!existing.tourTitle || existing.tourTitle === 'GetYourGuide Experience' || existing.tourTitle === 'Airbnb Experience')
        ? incoming.tourTitle
        : existing.tourTitle,
    fareOption: incoming.fareOption || existing.fareOption,
    customerName:
      incoming.customerName &&
      incoming.customerName !== 'GetYourGuide Customer' &&
      incoming.customerName !== 'Airbnb Guest' &&
      (!existing.customerName || existing.customerName === 'GetYourGuide Customer' || existing.customerName === 'Airbnb Guest')
        ? incoming.customerName
        : existing.customerName,
    customerEmail: incoming.customerEmail || existing.customerEmail,
    customerPhone: incoming.customerPhone || existing.customerPhone,
    pickup:
      incoming.pickup &&
      incoming.pickup !== 'As arranged with provider' &&
      (!existing.pickup || existing.pickup === 'As arranged with provider')
        ? incoming.pickup
        : existing.pickup,
    mapsUrl: incoming.mapsUrl || existing.mapsUrl,
    bookingUrl: incoming.bookingUrl || existing.bookingUrl,
    imageUrl: incoming.imageUrl || existing.imageUrl,
    price: incoming.price && incoming.price !== 'Paid' && incoming.price !== '€ 0.00' ? incoming.price : (existing.price || incoming.price),
    priceAmount: typeof incoming.priceAmount === 'number' && incoming.priceAmount > 0 ? incoming.priceAmount : existing.priceAmount,
    isReviewBooking: typeof incoming.priceAmount === 'number' && incoming.priceAmount > 0 ? incoming.isReviewBooking : existing.isReviewBooking,
    isLastMinute: incoming.isLastMinute || existing.isLastMinute,
    platform: incoming.platform || existing.platform,
    status: isCancelled ? 'cancelled' : incoming.isLastMinute || existing.isLastMinute ? 'last-minute' : 'confirmed',
  };
}

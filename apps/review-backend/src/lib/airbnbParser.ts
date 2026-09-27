import * as cheerio from 'cheerio';
import { BookingItem } from './types';

// Arabic to German Month Mapping
const ARABIC_TO_GERMAN_MONTHS: Record<string, { german: string; monthIndex: number }> = {
  'يناير': { german: 'Januar', monthIndex: 0 },
  'فبراير': { german: 'Februar', monthIndex: 1 },
  'مارس': { german: 'März', monthIndex: 2 },
  'أبريل': { german: 'April', monthIndex: 3 },
  'مايو': { german: 'Mai', monthIndex: 4 },
  'يونيو': { german: 'Juni', monthIndex: 5 },
  'يوليو': { german: 'Juli', monthIndex: 6 },
  'أغسطس': { german: 'August', monthIndex: 7 },
  'سبتمبر': { german: 'September', monthIndex: 8 },
  'أكتوبر': { german: 'Oktober', monthIndex: 9 },
  'نوفمبر': { german: 'November', monthIndex: 10 },
  'ديسمبر': { german: 'Dezember', monthIndex: 11 },
};

// Arabic Weekday to German Mapping
const ARABIC_TO_GERMAN_WEEKDAYS: Record<string, string> = {
  'الإثنين': 'Montag',
  'الاثنين': 'Montag',
  'الثلاثاء': 'Dienstag',
  'الأربعاء': 'Mittwoch',
  'الخميس': 'Donnerstag',
  'الجمعة': 'Freitag',
  'السبت': 'Samstag',
  'الأحد': 'Sonntag',
};

const ENGLISH_MONTHS: Record<string, { german: string; monthIndex: number }> = {
  'january': { german: 'Januar', monthIndex: 0 },
  'jan': { german: 'Januar', monthIndex: 0 },
  'february': { german: 'Februar', monthIndex: 1 },
  'feb': { german: 'Februar', monthIndex: 1 },
  'march': { german: 'März', monthIndex: 2 },
  'mar': { german: 'März', monthIndex: 2 },
  'april': { german: 'April', monthIndex: 3 },
  'apr': { german: 'April', monthIndex: 3 },
  'may': { german: 'Mai', monthIndex: 4 },
  'june': { german: 'Juni', monthIndex: 5 },
  'jun': { german: 'Juni', monthIndex: 5 },
  'july': { german: 'Juli', monthIndex: 6 },
  'jul': { german: 'Juli', monthIndex: 6 },
  'august': { german: 'August', monthIndex: 7 },
  'aug': { german: 'August', monthIndex: 7 },
  'september': { german: 'September', monthIndex: 8 },
  'sep': { german: 'September', monthIndex: 8 },
  'sept': { german: 'September', monthIndex: 8 },
  'october': { german: 'Oktober', monthIndex: 9 },
  'oct': { german: 'Oktober', monthIndex: 9 },
  'november': { german: 'November', monthIndex: 10 },
  'nov': { german: 'November', monthIndex: 10 },
  'december': { german: 'Dezember', monthIndex: 11 },
  'dec': { german: 'Dezember', monthIndex: 11 },
};

/**
 * Checks if the email is strictly an Airbnb EXPERIENCE booking.
 * Excludes normal Airbnb apartment/housing/stay bookings completely.
 */
export function isAirbnbEmail(email: {
  subject?: string;
  text?: string;
  html?: string;
  from?: string;
}): boolean {
  const fromStr = (email.from || '').toLowerCase();
  const subj = (email.subject || '').toLowerCase();
  const text = (email.text || '').toLowerCase();
  const html = (email.html || '').toLowerCase();
  const combined = `${subj}\n${text}\n${html}`;

  const isAirbnbSenderOrKeyword =
    fromStr.includes('airbnb') ||
    subj.includes('airbnb') ||
    text.includes('airbnb') ||
    html.includes('airbnb');

  if (!isAirbnbSenderOrKeyword) {
    return false;
  }

  // 1. STRICT APARTMENT / STAY EXCLUSION
  // If the email is for an apartment, flat, room, or residential listing, reject immediately.
  const isApartmentKeywords =
    subj.includes('حجز للإعلان') ||
    subj.includes('استفسار عن modern') ||
    subj.includes('استفسار بخصوص modern') ||
    subj.includes('هذا إيصال من airbnb لرحلتك') ||
    subj.includes('لرحلتك') ||
    subj.includes('إيصال') ||
    subj.includes('مرحبًا بك في airbnb') ||
    combined.includes('modern & cozy') ||
    combined.includes('madinaty') ||
    combined.includes('1br') ||
    combined.includes('2br') ||
    combined.includes('3br') ||
    combined.includes('منزل/شقة بالكامل') ||
    combined.includes('rooms/1740347207415646850') ||
    combined.includes('thread_type=home_booking') ||
    (combined.includes('/rooms/') && !combined.includes('/experiences/')) ||
    combined.includes('تسجيل الوصول') ||
    combined.includes('تسجيل المغادرة') ||
    combined.includes('أنت على أتم الاستعداد للسفر') ||
    combined.includes('ساقية مكي') ||
    combined.includes('شقق للايجار') ||
    combined.includes('فندقية علي النيل') ||
    combined.includes('مكان إقامة') ||
    combined.includes('إقامتك') ||
    (combined.includes('check-in') && combined.includes('check-out') && !combined.includes('/experiences/'));

  if (isApartmentKeywords) {
    return false;
  }

  // 2. EXCLUDE SYSTEM, REMINDERS & MARKETING NOTIFICATIONS
  const isSystemExcluded =
    subj.includes('security code') ||
    subj.includes('verification code') ||
    subj.includes('رمز الأمان') ||
    subj.includes('رمز التحقق') ||
    subj.includes('we updated our terms') ||
    subj.includes('leave a review') ||
    subj.includes('write a review') ||
    subj.includes('تمت إضافة تقييم') ||
    subj.includes('شكرًا على طلبك لإضافة تجربة') ||
    subj.includes('تمت الموافقة على تجربة') ||
    subj.includes('تحميل المستندات المطلوبة') ||
    subj.includes('تذكير بشأن حجز') ||
    subj.includes('تذكير:') ||
    subj.includes('reminder:') ||
    subj.includes('لديك رسالة جديدة') ||
    subj.includes('رسالة جديدة من فريق الدعم') ||
    subj.includes('رسالة من دعم airbnb') ||
    subj.includes('أرسلنا دفعة عائد') ||
    subj.includes('مطلوب اتخاذ إجراء');

  if (isSystemExcluded) {
    return false;
  }

  // 3. MUST BE AN EXPERIENCE (Experience Booking Confirmation or Experience Cancellation)
  const isExperience =
    subj.includes('حجز التجربة') ||
    subj.includes('تم حجز التجربة') ||
    subj.includes('تجربة السفر') ||
    (subj.includes('private hallstatt tour') && (subj.includes('تم إلغاء') || subj.includes('حجز'))) ||
    subj.includes('إلغاء حجز') ||
    combined.includes('airbnb.com/experiences/') ||
    combined.includes('airbnb.com/hosting/experience/') ||
    combined.includes('تم حجز التجربة') ||
    combined.includes('تم إلغاء حجز') ||
    combined.includes('ألغى الضيف') ||
    combined.includes('booked an experience') ||
    combined.includes('entdeckung gebucht');

  return isExperience;
}

/**
 * Translates Arabic tour title to German.
 */
export function translateTitleToGerman(title: string): string {
  if (!title) return 'Private Tour nach Hallstatt ab Salzburg mit dem Auto';

  const lower = title.toLowerCase().trim();

  // If title mentions Hallstatt
  if (lower.includes('هالستات') || lower.includes('hallstatt')) {
    if (lower.includes('سالزبورغ') || lower.includes('salzburg')) {
      return 'Private Tour nach Hallstatt ab Salzburg mit dem Auto';
    }
    return 'Private Hallstatt Erlebnis-Tour';
  }

  // If title mentions Salzburg only
  if (lower.includes('سالزبورغ') || lower.includes('salzburg')) {
    return 'Private Salzburg Stadt- & Panorama-Tour';
  }

  // Generic translation replacements from Arabic to German
  let translated = title;
  const replacements: [RegExp, string][] = [
    [/جولة خاصة/gi, 'Private Tour'],
    [/جولة يوم كامل/gi, 'Ganztagstour'],
    [/جولة نصف يوم/gi, 'Halbtagstour'],
    [/جولة/gi, 'Tour'],
    [/في هالستات/gi, 'nach Hallstatt'],
    [/هالستات/gi, 'Hallstatt'],
    [/انطلاقاً من سالزبورغ/gi, 'ab Salzburg'],
    [/من سالزبورغ/gi, 'ab Salzburg'],
    [/سالزبورغ/gi, 'Salzburg'],
    [/بالسيارة/gi, 'mit dem Auto'],
    [/سيارة خاصة/gi, 'im Privatwagen'],
    [/تجربة خاصة/gi, 'Privates Erlebnis'],
    [/تجربة/gi, 'Erlebnis'],
    [/نمسا/gi, 'Österreich'],
  ];

  for (const [pattern, rep] of replacements) {
    translated = translated.replace(pattern, rep);
  }

  return translated.trim();
}

/**
 * Translates and normalizes date/time string from Arabic to German.
 * e.g.:
 * "الخميس، 3 ديسمبر 2026 · 10:00 ص – 4:45 م CET"
 * -> "Donnerstag, 3. Dezember 2026 · 10:00 – 16:45 Uhr CET"
 */
export function translateDateToGerman(dateStr: string): string {
  if (!dateStr) return 'Geplante Tour';

  let result = dateStr;

  // Replace Arabic comma with Latin comma
  result = result.replace(/،/g, ',');

  // 1. Translate Arabic weekdays
  for (const [arDay, deDay] of Object.entries(ARABIC_TO_GERMAN_WEEKDAYS)) {
    result = result.replace(new RegExp(arDay, 'g'), deDay);
  }

  // 2. Translate Arabic months and insert standard German dot after day number if needed
  for (const [arMonth, { german }] of Object.entries(ARABIC_TO_GERMAN_MONTHS)) {
    if (result.includes(arMonth)) {
      result = result.replace(new RegExp(`(\\d{1,2})\\s+${arMonth}`, 'g'), `$1. ${german}`);
      result = result.replace(new RegExp(arMonth, 'g'), german);
    }
  }

  // 3. Convert 12h Arabic time format (ص = AM, م = PM) to standard German 24h format
  // Pattern: "10:00 ص – 4:45 م" or "10:00 ص - 4:45 م"
  result = result.replace(
    /(\d{1,2}):(\d{2})\s*(ص|م)\s*(?:–|-)\s*(\d{1,2}):(\d{2})\s*(ص|م)/g,
    (_, h1, m1, p1, h2, m2, p2) => {
      let hour1 = parseInt(h1, 10);
      let hour2 = parseInt(h2, 10);
      if (p1 === 'م' && hour1 < 12) hour1 += 12;
      if (p1 === 'ص' && hour1 === 12) hour1 = 0;
      if (p2 === 'م' && hour2 < 12) hour2 += 12;
      if (p2 === 'ص' && hour2 === 12) hour2 = 0;
      const t1 = `${String(hour1).padStart(2, '0')}:${m1}`;
      const t2 = `${String(hour2).padStart(2, '0')}:${m2}`;
      return `${t1} – ${t2} Uhr`;
    }
  );

  // Single time: e.g. "10:00 ص"
  result = result.replace(/(\d{1,2}):(\d{2})\s*(ص|م)/g, (_, h, m, p) => {
    let hour = parseInt(h, 10);
    if (p === 'م' && hour < 12) hour += 12;
    if (p === 'ص' && hour === 12) hour = 0;
    return `${String(hour).padStart(2, '0')}:${m} Uhr`;
  });

  // Clean up any remaining Arabic words
  result = result
    .replace(/تاريخ البدء/g, '')
    .replace(/تاريخ الانتهاء/g, '')
    .replace(/عرض في التقويم/g, '')
    .replace(/\s+/g, ' ')
    .trim();

  return result;
}

/**
 * Translates participants string from Arabic/English to German.
 * e.g. "2 أشخاص بالغين, مجموعة خاصة" -> "2 Erwachsene, Private Gruppe"
 * "6 أشخاص" -> "6 Personen"
 */
export function translateParticipantsToGerman(partStr: string): string {
  if (!partStr || partStr.startsWith('http') || partStr.includes('airbnb')) {
    return '1 Person, Private Gruppe';
  }

  let result = partStr;

  // Single guest
  result = result.replace(/1\s*(?:ضيف|شخص|guest)/gi, '1 Gast');

  // Numbers + Arabic words
  result = result.replace(/(\d+)\s*(?:أشخاص\s+بالغين|بالغين)/g, '$1 Erwachsene');
  result = result.replace(/(\d+)\s*أشخاص/g, '$1 Personen');
  result = result.replace(/(\d+)\s*(?:ضيوف|ضيف)/g, '$1 Gäste');
  result = result.replace(/(\d+)\s*(?:أطفال|طفل)/g, '$1 Kinder');
  result = result.replace(/مجموعة خاصة/g, 'Private Gruppe');
  result = result.replace(/أشخاص بالغين/g, 'Erwachsene');
  result = result.replace(/شخص بالغ/g, 'Erwachsener');

  // English equivalents to German
  result = result.replace(/(\d+)\s*adults?/gi, '$1 Erwachsene');
  result = result.replace(/(\d+)\s*guests?/gi, '$1 Gäste');
  result = result.replace(/private group/gi, 'Private Gruppe');

  return result.replace(/،/g, ',').replace(/\s+/g, ' ').trim();
}

/**
 * Parses Airbnb Experience booking confirmation or cancellation emails.
 * Converts extracted fields from Arabic to German.
 */
export function parseAirbnbBooking(
  emailContent: {
    subject?: string;
    text?: string;
    html?: string;
    date?: Date | string;
    messageId?: string;
    from?: string;
  }
): BookingItem | null {
  if (!isAirbnbEmail(emailContent)) {
    return null;
  }

  const text = (emailContent.text || '').replace(/\r\n/g, '\n');
  const html = emailContent.html || '';
  const subject = emailContent.subject || '';

  let combinedText = text;
  let bookingUrl = '';
  let imageUrl = '';
  let experienceId = '';

  // Extract from HTML with Cheerio if available
  if (html) {
    try {
      const $ = cheerio.load(html);

      // Find reservation details / itinerary link
      $('a').each((_, el) => {
        const href = $(el).attr('href') || '';
        const linkText = $(el).text().trim().toLowerCase();

        if (
          href.includes('airbnb.com/hosting/experience') ||
          href.includes('airbnb.com/experiences') ||
          href.includes('airbnb.com/hosting/reservations') ||
          linkText.includes('عرض الحجز') ||
          linkText.includes('view reservation') ||
          linkText.includes('view booking')
        ) {
          if (!bookingUrl && href.startsWith('http')) {
            bookingUrl = href;
          }
        }

        const expMatch = href.match(/experience[s]?\/([0-9]+)/i);
        if (expMatch && !experienceId) {
          experienceId = expMatch[1];
        }
      });

      // Find hero experience image from Airbnb CDN
      $('img').each((_, el) => {
        const src = $(el).attr('src') || '';
        if (
          (src.includes('muscache.com') || src.includes('airbnb')) &&
          (src.includes('/im/pictures/') || src.includes('/pictures/'))
        ) {
          if (!imageUrl) {
            imageUrl = src;
          }
        }
      });

      if (!combinedText) {
        combinedText = $.text();
      }
    } catch {
      // fallback
    }
  }

  // 1. Reference Number / Confirmation Code (e.g. TAN25KB4 or EXP-7282638)
  let referenceNumber = '';

  const refCodeMatch =
    combinedText.match(/(?:رمز التأكيد|Confirmation\s+code|Bestätigungscode|Code\s+de\s+confirmation)[\s\S]{1,60}?\b([A-Z0-9]{8,12})\b/i);

  const EXCLUDED_WORDS = [
    'AIRBNB', 'GMAIL', 'SEPTEMBER', 'DECEMBER', 'CONFIRMED', 'EXPERIENCE',
    'SALZBURG', 'HALLSTATT', 'AUSTRIA', 'GERMANY', 'PRIVATE', 'TOUR',
    'DETAILS', 'RESERVATION', 'INTERSTITIAL'
  ];

  if (refCodeMatch) {
    const candidate = refCodeMatch[1].trim().toUpperCase();
    if (!EXCLUDED_WORDS.includes(candidate)) {
      referenceNumber = candidate;
    }
  }

  // Check URL
  if (!referenceNumber && bookingUrl) {
    const urlRefMatch = bookingUrl.match(/(?:code=|details\/)([A-Z0-9]{8,12})/i);
    if (urlRefMatch) {
      const cand = urlRefMatch[1].toUpperCase();
      if (!EXCLUDED_WORDS.includes(cand)) {
        referenceNumber = cand;
      }
    }
  }

  // If still no confirmation code, use experience ID or stable identifier
  if (!referenceNumber && experienceId) {
    referenceNumber = `EXP-${experienceId}`;
  }

  // 2. Customer / Guest Name
  let customerName = '';

  // Arabic pattern: "تم حجز التجربة من قِبل Thanh في 18 سبتمبر" or "تم إلغاء الحجز من قِبل THANH"
  const arGuestMatch =
    subject.match(/(?:تم\s+حجز\s+التجربة\s+من\s+قِ?بل|تم\s+إلغاء\s+حجز[^\n]+من\s+قِ?بل)\s+([^\n،]+?)(?:\s+في|\s*$)/i) ||
    combinedText.match(/(?:تم\s+حجز\s+التجربة\s+من\s+قِ?بل|تم\s+إلغاء\s+الحجز\s+من\s+قِ?بل)\s+([^\n،]+)/i);

  if (arGuestMatch) {
    const cand = cleanText(arGuestMatch[1]);
    if (cand && !cand.includes('الضيوف') && !cand.includes('دعم') && !cand.includes('Airbnb')) {
      customerName = cand;
    }
  }

  // English pattern
  if (!customerName) {
    const enGuestMatch =
      combinedText.match(/Experience\s+booked\s+by\s+([^\n,]+?)\s+on/i) ||
      subject.match(/Reservation\s+confirmed\s*[-:]\s*([^\n,]+)/i);
    if (enGuestMatch) {
      customerName = cleanText(enGuestMatch[1]);
    }
  }

  if (!customerName || customerName.includes('الضيوف')) {
    customerName = 'Airbnb Gast';
  }

  // 3. Tour Title (translated to German)
  let rawTourTitle = '';

  if (
    combinedText.toLowerCase().includes('private hallstatt tour from salzburg by car') ||
    subject.toLowerCase().includes('private hallstatt tour') ||
    combinedText.includes('جولة خاصة في هالستات')
  ) {
    rawTourTitle = 'Private Tour nach Hallstatt ab Salzburg mit dem Auto';
  } else {
    // Look above "المضيف: Aya"
    const arTitleMatch =
      combinedText.match(/([^\n]+)\n+(?:المضيف|Host|Gastgeber)\s*:\s*([^\n]+)/i) ||
      combinedText.match(/([^\n]+)\n+([^\n]+)\s*:\s*(?:المضيف|Host)/i);

    if (arTitleMatch) {
      const candidate = cleanText(arTitleMatch[1]);
      if (candidate && candidate.length > 5 && !candidate.toLowerCase().includes('http')) {
        rawTourTitle = candidate;
      }
    }
  }

  if (!rawTourTitle) {
    const match = combinedText.match(/(?:جولة\s+خاصة\s+في\s+[^\n]+|Private\s+Tour\s+[^\n]+)/i);
    if (match) {
      rawTourTitle = cleanText(match[0]);
    }
  }

  // Translate title to German
  const tourTitle = translateTitleToGerman(rawTourTitle || 'Private Tour nach Hallstatt ab Salzburg mit dem Auto');

  // 4. Date & Time (translated to German)
  let rawDateStr = '';
  let timestamp: number = Date.now();

  // Pattern 1: Table format e.g.
  // الجمعة ... 18 سبتمبر 2026 ... 10:00 ص
  const tableDateMatch = combinedText.match(
    /(?:الجمعة|السبت|الأحد|الإثنين|الاثنين|الثلاثاء|الأربعاء)[\s\S]{1,50}?(\d{1,2}\s+(?:يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر)(?:\s+\d{4})?)[\s\S]{1,50}?(\d{1,2}:\d{2}\s*(?:ص|م))/i
  );

  if (tableDateMatch) {
    const dayAndMonth = tableDateMatch[1];
    const startTime = tableDateMatch[2];
    const endTimeMatch = combinedText.match(/(\d{1,2}:\d{2}\s*م)/);
    const endTime = endTimeMatch ? endTimeMatch[1] : '4:45 م';
    const dayOfWeek = (combinedText.match(/(الجمعة|السبت|الأحد|الإثنين|الاثنين|الثلاثاء|الأربعاء)/) || ['Freitag'])[0];
    rawDateStr = `${dayOfWeek}، ${dayAndMonth} · ${startTime} – ${endTime}`;
  }

  // Pattern 2: Single line: "الخميس، 3 ديسمبر 2026 · 10:00 ص – 4:45 م CET"
  if (!rawDateStr) {
    const arDateMatch = combinedText.match(/(?:التاريخ\s+والوقت|Date\s+and\s+time)\s*\n+([^\n]+)/i);
    if (arDateMatch) {
      rawDateStr = cleanText(arDateMatch[1]);
    }
  }

  // Pattern 3: Subject date: "في 18 سبتمبر"
  if (!rawDateStr) {
    const subjDateMatch = subject.match(/في\s+(\d{1,2}\s+(?:يناير|فبراير|مارس|أبريل|مايو|يونيو|يوليو|أغسطس|سبتمبر|أكتوبر|نوفمبر|ديسمبر))/i);
    if (subjDateMatch) {
      rawDateStr = `Freitag, ${subjDateMatch[1]} 2026 · 10:00 – 16:45 Uhr`;
    }
  }

  // Translate date to German
  const dateGerman = translateDateToGerman(rawDateStr);

  // Compute timestamp
  const parsedTs = parseDateStringToTimestamp(rawDateStr || dateGerman);
  if (parsedTs) {
    timestamp = parsedTs;
  } else if (emailContent.date) {
    timestamp = new Date(emailContent.date).getTime();
  }

  // 5. Participants / Guests (translated to German)
  const normText = combinedText.replace(/[\u200E\u200F\u061C\u202A-\u202E\u00A0]/g, ' ');

  let rawParticipants = '';
  // Check count e.g. "6 أشخاص", "1 ضيف", or "2 أشخاص بالغين"
  const countMatch = normText.match(/(\d+\s*(?:أشخاص\s+بالغين|أشخاص|adults?|Gäste|guests?|ضيوف|ضيف))/i);
  if (countMatch) {
    rawParticipants = cleanText(countMatch[1]);
  } else {
    const guestsMatch = normText.match(/(?:الضيوف|Guests|Gäste)\s*\n+([^\n]+)/i);
    if (guestsMatch && !guestsMatch[1].includes('http')) {
      rawParticipants = cleanText(guestsMatch[1]);
    } else {
      rawParticipants = '1 Person';
    }
  }

  const participants = translateParticipantsToGerman(rawParticipants);

  // 6. Pricing & Payout
  let price = '€ 0.00';
  let priceAmount: number | undefined = undefined;

  // 6a. Unit price x count: e.g. "€ 25.00 x 1 ضيف € 25.00"
  const unitMatch = normText.match(/€\s*([\d.,]+)\s*x\s*(\d+)\s*(?:ضيف|ضيوف|guest|gäste|personen|أشخاص)/i);
  if (unitMatch) {
    const unitPrice = parseFloat(unitMatch[1].replace(/,/g, '.'));
    const count = parseInt(unitMatch[2], 10);
    if (!isNaN(unitPrice) && !isNaN(count) && unitPrice > 0) {
      priceAmount = unitPrice * count;
      price = `€ ${(unitPrice * count).toFixed(2)}`;
    }
  }

  // 6b. Base price: e.g. "السعر الأساسي € 400.00"
  if (priceAmount === undefined) {
    const baseMatch =
      normText.match(/(?:السعر\s+الأساسي|Base\s+price|Grundpreis)\s*€?\s*([\d.,]+)\s*€?/i) ||
      normText.match(/€\s*([\d.,]+)\s*(?:السعر\s+الأساسي|Base\s+price|Grundpreis)/i);
    if (baseMatch) {
      const num = parseFloat(baseMatch[1].replace(/,/g, '.'));
      if (!isNaN(num) && num > 0) {
        priceAmount = num;
        price = `€ ${num.toFixed(2)}`;
      }
    }
  }

  // 6c. Net Payout: e.g. "الإجمالي (EUR) € 19.00" or "Gesamtauszahlung € 304.00"
  if (priceAmount === undefined) {
    const payoutMatch =
      normText.match(/(?:الإجمالي|اإلجمالي|Total\s+payout|Gesamtauszahlung)\s*(?:\([^)]*\))?\s*€?\s*([\d.,]+)\s*€?/i) ||
      normText.match(/€\s*([\d.,]+)\s*(?:الإجمالي|اإلجمالي|Total)/i) ||
      normText.match(/([\d.,]+)\s*€\s*(?:\([^)]*\))?\s*(?:الإجمالي|اإلجمالي|Total|Gesamtauszahlung)/i);
    if (payoutMatch) {
      const num = parseFloat(payoutMatch[1].replace(/,/g, '.'));
      if (!isNaN(num) && num > 0) {
        priceAmount = num;
        price = `€ ${num.toFixed(2)}`;
      }
    }
  }

  // 6d. Earnings section generic match:
  if (priceAmount === undefined) {
    const earningsMatch = normText.match(/(?:الأرباح|Earnings)[\s\S]{0,100}?€\s*([\d.,]+)/i);
    if (earningsMatch) {
      const num = parseFloat(earningsMatch[1].replace(/,/g, '.'));
      if (!isNaN(num) && num > 0) {
        priceAmount = num;
        price = `€ ${num.toFixed(2)}`;
      }
    }
  }

  // 6e. Any EUR fallback
  if (priceAmount === undefined) {
    const anyEur = normText.match(/€\s*([\d.,]+)/) || normText.match(/([\d.,]+)\s*€/);
    if (anyEur) {
      const num = parseFloat(anyEur[1].replace(/,/g, '.'));
      if (!isNaN(num) && num > 0) {
        priceAmount = num;
        price = `€ ${num.toFixed(2)}`;
      }
    }
  }

  if (priceAmount === undefined) {
    priceAmount = 0;
    price = '€ 0.00';
  }

  // Any booking under 30 euros is classified as a review booking
  const isReviewBooking = typeof priceAmount === 'number' && priceAmount > 0 ? priceAmount < 30 : false;

  // 7. Pickup / Location in German
  const pickup = 'Salzburg, Österreich (Hotelabholung nach Vereinbarung)';

  // Hero image
  if (!imageUrl) {
    imageUrl = 'https://images.unsplash.com/photo-1516483638261-f4dbaf036963?auto=format&fit=crop&w=1200&q=80';
  }

  // 8. Cancellation status
  const lowerSubj = subject.toLowerCase();
  const lowerComb = combinedText.toLowerCase();
  const isCancelled =
    lowerSubj.includes('cancelled') ||
    lowerSubj.includes('canceled') ||
    lowerSubj.includes('storniert') ||
    lowerSubj.includes('تم إلغاء حجز') ||
    lowerComb.includes('ألغى الضيف') ||
    lowerComb.includes('تم إلغاء الحجز') ||
    lowerComb.includes('حجز مُلغى');

  const ref = referenceNumber || (customerName !== 'Airbnb Gast' ? `AB-${customerName.toUpperCase().replace(/\s+/g, '')}` : `AB-${Date.now().toString(36).toUpperCase()}`);
  const id = `airbnb_${ref}`;

  const receivedAt = emailContent.date
    ? new Date(emailContent.date).toISOString()
    : new Date().toISOString();

  return {
    id,
    referenceNumber: ref,
    tourTitle,
    fareOption: 'Private Gruppe',
    date: dateGerman || 'Geplante Tour',
    timestamp,
    participants: participants || '1 Person, Private Gruppe',
    customerName,
    customerEmail: 'airbnb-guest@reply.airbnb.com',
    customerPhone: '',
    customerLanguage: 'Arabisch',
    tourLanguage: 'Deutsch',
    pickup,
    bookingUrl: bookingUrl || `https://www.airbnb.com/hosting/experience/${experienceId || 'details'}`,
    imageUrl,
    price,
    priceAmount,
    isReviewBooking,
    isLastMinute: false,
    receivedAt,
    status: isCancelled ? 'cancelled' : 'confirmed',
    platform: 'airbnb',
  };
}

/**
 * Parses date string (Arabic, German, English) into millisecond timestamp.
 */
function parseDateStringToTimestamp(dateStr: string): number | null {
  try {
    // 1. Arabic month match
    for (const [arMonth, { monthIndex }] of Object.entries(ARABIC_TO_GERMAN_MONTHS)) {
      if (dateStr.includes(arMonth)) {
        const dayMatch = dateStr.match(new RegExp(`(\\d{1,2})\\s+${arMonth}(?:\\s+(\\d{4}))?`));
        if (dayMatch) {
          const day = parseInt(dayMatch[1], 10);
          const year = dayMatch[2] ? parseInt(dayMatch[2], 10) : 2026;
          return new Date(year, monthIndex, day, 10, 0).getTime();
        }
      }
    }

    // 2. German month match
    const GERMAN_MONTHS_MAP: Record<string, number> = {
      'januar': 0, 'februar': 1, 'märz': 2, 'april': 3, 'mai': 4, 'juni': 5,
      'juli': 6, 'august': 7, 'september': 8, 'oktober': 9, 'november': 10, 'dezember': 11,
    };
    for (const [deMonth, monthIndex] of Object.entries(GERMAN_MONTHS_MAP)) {
      const lower = dateStr.toLowerCase();
      if (lower.includes(deMonth)) {
        const match = lower.match(new RegExp(`(\\d{1,2})\\.?\\s+${deMonth}(?:\\s+(\\d{4}))?`));
        if (match) {
          const day = parseInt(match[1], 10);
          const year = match[2] ? parseInt(match[2], 10) : 2026;
          return new Date(year, monthIndex, day, 10, 0).getTime();
        }
      }
    }

    // 3. English month match
    for (const [enMonth, { monthIndex }] of Object.entries(ENGLISH_MONTHS)) {
      const lower = dateStr.toLowerCase();
      if (lower.includes(enMonth)) {
        const match = lower.match(new RegExp(`(\\d{1,2})\\s+${enMonth}(?:\\s+(\\d{4}))?`));
        if (match) {
          const day = parseInt(match[1], 10);
          const year = match[2] ? parseInt(match[2], 10) : 2026;
          return new Date(year, monthIndex, day, 10, 0).getTime();
        }
      }
    }
  } catch {
    // ignore
  }
  return null;
}

function cleanText(text: string): string {
  return text
    .replace(/\[.*?\]\(.*?\)/g, '')
    .replace(/<[^>]*>/g, '')
    .replace(/\s+/g, ' ')
    .trim();
}

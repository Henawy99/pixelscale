import * as cheerio from 'cheerio';
import { BookingItem } from './types';

/**
 * Parses GetYourGuide booking emails (both HTML and text/markdown representations).
 */
export function parseGetYourGuideBooking(
  emailContent: {
    subject?: string;
    text?: string;
    html?: string;
    date?: Date | string;
    messageId?: string;
  }
): BookingItem | null {
  const text = (emailContent.text || '').replace(/\r\n/g, '\n');
  const html = emailContent.html || '';
  const subject = emailContent.subject || '';

  const lowerSubj = subject.toLowerCase();
  const lowerText = text.toLowerCase();

  // Exclude administrative & support survey emails
  const isSupportTicket =
    lowerSubj.includes('we value your feedback') ||
    lowerSubj.includes('ticket received') ||
    lowerSubj.includes('reply received') ||
    lowerSubj.includes('refund request') ||
    lowerSubj.includes('ticket id') ||
    lowerSubj.includes('product setup') ||
    lowerSubj.includes('product configuration') ||
    lowerSubj.includes('email not in use') ||
    lowerSubj.includes('zoho workplace') ||
    lowerSubj.includes('new email address added');

  if (isSupportTicket) {
    return null;
  }

  // Quick check if this is a GetYourGuide booking email
  const isGygBooking =
    lowerSubj.includes('booking') ||
    lowerSubj.includes('getyourguide') ||
    lowerText.includes('supply partner') ||
    lowerText.includes('reference number') ||
    lowerText.includes('last-minute') ||
    html.toLowerCase().includes('getyourguide');

  if (!isGygBooking && !text.includes('GYG')) {
    return null;
  }

  // Fallback text extraction if html is rich
  let combinedText = text;
  let mapsUrl = '';
  let bookingUrl = '';

  if (html) {
    try {
      const $ = cheerio.load(html);
      // Look for Google Maps link
      $('a').each((_, el) => {
        const href = $(el).attr('href') || '';
        const linkText = $(el).text().trim().toLowerCase();
        if (linkText.includes('google maps') || href.includes('maps.google') || href.includes('goo.gl/maps')) {
          if (!mapsUrl) mapsUrl = href;
        }
        if (linkText.includes('open booking') || linkText.includes('booking details')) {
          if (!bookingUrl) bookingUrl = href;
        }
      });

      if (!combinedText) {
        combinedText = $.text();
      }
    } catch {
      // fallback to text
    }
  }

  // Also check markdown link syntax in text
  // [Open in Google Maps](https://...)
  const mapsMatch = combinedText.match(/\[(?:Open in Google Maps|Google Maps)\]\((https?:\/\/[^\s)]+)\)/i);
  if (mapsMatch && !mapsUrl) {
    mapsUrl = mapsMatch[1];
  }

  // [Open booking](https://...)
  const bookingMatch = combinedText.match(/\[(?:Open booking|View booking)\]\((https?:\/\/[^\s)]+)\)/i);
  if (bookingMatch && !bookingUrl) {
    bookingUrl = bookingMatch[1];
  }

  // Reference number: GYG followed by alphanumeric (e.g. GYG6H73M6WMV or [GYG6H73M6WMV](...))
  let referenceNumber = '';
  const refMatch = combinedText.match(/Reference(?:\s+number)?[\s\S]*?(?:\[)?(GYG[A-Z0-9]+)(?:\]|\b)/i) ||
                   combinedText.match(/\b(GYG[A-Z0-9]{6,14})\b/i);
  if (refMatch) {
    referenceNumber = refMatch[1].trim();
  }

  // Subject pattern: "Vanessa Eduave has messaged you about booking GYGZGZQ66A2Q"
  const msgSubjMatch = subject.match(/([A-Za-z\s]+)\s+has\s+messaged\s+you\s+about\s+booking\s+(GYG[A-Z0-9]+)/i);
  if (msgSubjMatch) {
    if (!referenceNumber) referenceNumber = msgSubjMatch[2].trim();
  }

  // Reference number link might also be bookingUrl
  const refLinkMatch = combinedText.match(/\[GYG[A-Z0-9]+\]\((https?:\/\/[^\s)]+)\)/i);
  if (refLinkMatch && !bookingUrl) {
    bookingUrl = refLinkMatch[1];
  }

  // Check if last minute
  const isLastMinute =
    combinedText.toLowerCase().includes('last-minute') ||
    subject.toLowerCase().includes('last-minute');

  // Tour Title & Option
  let tourTitle = '';
  let fareOption = '';
  let imageUrl = '';

  const imgMatch = combinedText.match(/https:\/\/cdn\.getyourguide\.com\/img\/tour\/[^\s)\]"]+/i) ||
                   html.match(/https:\/\/cdn\.getyourguide\.com\/img\/tour\/[^\s)\]"]+/i);
  if (imgMatch) {
    imageUrl = imgMatch[0];
  }

  const isNotImageOrUrl = (str: string): boolean => {
    if (!str) return false;
    const s = str.trim();
    if (s.startsWith('http') || s.startsWith('[') || s.includes('.png') || s.includes('.jpg') || s.includes('cdn.getyourguide')) {
      return false;
    }
    return s.length > 3 && !s.toLowerCase().includes('ticket-booking');
  };

  const linesAfterHeader = combinedText
    .split(/\n+/)
    .map(cleanText)
    .filter(Boolean);

  const headerIndex = linesAfterHeader.findIndex((l) =>
    /(?:received\s+(?:a\s+)?(?:last-minute\s+)?booking|offer\s+has\s+been\s+booked|new\s+booking\s+received|booking\s+confirmed)/i.test(l)
  );
  if (headerIndex !== -1) {
    for (let i = headerIndex + 1; i < Math.min(headerIndex + 6, linesAfterHeader.length); i++) {
      const line = linesAfterHeader[i];
      if (isNotImageOrUrl(line) && !line.toLowerCase().includes('reference') && !line.toLowerCase().includes('great news')) {
        if (!tourTitle) {
          tourTitle = line;
        } else if (!fareOption && line !== tourTitle && (line.includes('Fare') || line.includes('Adult') || line.includes('Admission') || line.includes('Option') || line.includes('Group') || line.includes('Person') || line.includes('Ticket') || line.includes('Private') || line.includes('Standard'))) {
          fareOption = line;
          break;
        }
      }
    }
  }

  // Fallback tour title from "Tour:" label (e.g. cancellation emails), subject, or line before Reference number
  if (!tourTitle) {
    const tourLabelMatch = combinedText.match(/Tour(?:\s*name)?(?:\s*:)?\s*\n+([^\n]+)/i);
    if (tourLabelMatch && isNotImageOrUrl(tourLabelMatch[1])) {
      tourTitle = cleanText(tourLabelMatch[1]);
    }
  }

  if (!tourTitle) {
    const beforeRefMatch = combinedText.match(/([^\n]+)\n+Reference\s+number/i);
    if (beforeRefMatch && isNotImageOrUrl(beforeRefMatch[1])) {
      tourTitle = cleanText(beforeRefMatch[1]);
    } else if (subject) {
      const cleanSubj = subject
        .replace(/^(?:Urgent:\s*)?(?:New booking received\s*-\s*[A-Z0-9]+\s*-\s*)?/i, '')
        .replace(/^(?:Fwd:\s*|Re:\s*)?(?:New booking:\s*|GetYourGuide:\s*)?/i, '')
        .trim();
      if (isNotImageOrUrl(cleanSubj)) {
        tourTitle = cleanSubj;
      }
    }
  }

  // Date
  // Date\nSeptember 26, 2026, 10:00 AM
  let date = '';
  const dateMatch = combinedText.match(/Date\s*\n+([^\n]+)/i);
  if (dateMatch) {
    date = cleanText(dateMatch[1]);
  }

  // Number of participants
  // Number of participants\n1 x Adult (Age 18 - 99)
  let participants = '';
  const partMatch = combinedText.match(/Number\s+of\s+participants\s*\n+([^\n]+)/i);
  if (partMatch) {
    participants = cleanText(partMatch[1]);
  }

  // Main customer
  // Main customer\nMarcel Reiner[customer-5mnycnkorphuz6b4@reply.getyourguide.com](mailto:...)
  let customerName = '';
  let customerEmail = '';
  let customerPhone = '';
  let customerLanguage = '';

  const customerBlockMatch = combinedText.match(
    /Main\s+customer\s*\n+([^\n]+)(?:\n+Phone:\s*([^\n]+))?(?:\n+Language:\s*([^\n]+))?/i
  );

  if (customerBlockMatch) {
    const rawNameAndEmail = customerBlockMatch[1];
    // Might contain Markdown link or mailto
    const emailMatch = rawNameAndEmail.match(/(?:\[)?([a-zA-Z0-9._%+-]+@reply\.getyourguide\.com|[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})(?:\])?/i);
    if (emailMatch) {
      customerEmail = emailMatch[1];
      customerName = cleanText(rawNameAndEmail.replace(/\[?[a-zA-Z0-9._%+-]+@[^\]\s)]+\]?(?:\(mailto:[^)]+\))?/g, ''));
    } else {
      customerName = cleanText(rawNameAndEmail);
    }
  }

  if (!customerName && msgSubjMatch) {
    customerName = cleanText(msgSubjMatch[1]);
  }

  // Fallback customer name from "Name:" or "Customer:" label (e.g. cancellation emails)
  if (!customerName) {
    const nameMatch = combinedText.match(/(?:Customer(?:\s+name)?|Name)\s*:\s*\n*([^\n]+)/i);
    if (nameMatch && isNotImageOrUrl(nameMatch[1])) {
      customerName = cleanText(nameMatch[1]);
    }
  }

  // Separate Phone match
  const phoneMatch = combinedText.match(/Phone:\s*([+0-9\s\-()]+)/i);
  if (phoneMatch) {
    customerPhone = cleanText(phoneMatch[1]);
  }

  // Customer Language
  const langMatch = combinedText.match(/Main\s+customer[\s\S]*?Language:\s*([A-Za-z]+)/i) ||
                    combinedText.match(/\bLanguage:\s*([A-Za-z]+)/i);
  if (langMatch) {
    customerLanguage = cleanText(langMatch[1]);
  }

  // Tour Language
  // Tour language\nGerman (Live tour guide)
  let tourLanguage = '';
  const tourLangMatch = combinedText.match(/Tour\s+language\s*\n+([^\n]+)/i);
  if (tourLangMatch) {
    tourLanguage = cleanText(tourLangMatch[1]);
  }

  // Pickup
  // Pickup\nMünchen Hauptbahnhof, Bayerstraße, München, Deutschland[Open in Google Maps](...)
  let pickup = '';
  const pickupMatch = combinedText.match(/Pickup\s*\n+([^\n]+)/i);
  if (pickupMatch) {
    let rawPickup = pickupMatch[1];
    rawPickup = rawPickup.replace(/\[Open in Google Maps\]\([^)]+\)/gi, '');
    pickup = cleanText(rawPickup);
  }

  // Price
  // Price\n€ 9.60
  let price = '';
  const priceMatch = combinedText.match(/Price\s*\n+([^\n]+)/i);
  if (priceMatch) {
    price = cleanText(priceMatch[1]);
  }

  // Parse numeric amount in Euros
  let priceAmount: number | undefined = undefined;
  if (price) {
    const numericStr = price.replace(/[^0-9.,]/g, '').replace(',', '.');
    const parsed = parseFloat(numericStr);
    if (!isNaN(parsed)) {
      priceAmount = parsed;
    }
  }

  // Any booking under 30 euros is classified as a review booking
  const isReviewBooking = typeof priceAmount === 'number' ? priceAmount < 30 : false;

  // If still missing reference number, generate fallback or abort
  if (!referenceNumber && !tourTitle) {
    return null;
  }

  const id = referenceNumber || `bk_${Date.now()}_${Math.random().toString(36).substring(2, 7)}`;
  const receivedAt = emailContent.date
    ? new Date(emailContent.date).toISOString()
    : new Date().toISOString();

  // Try to parse timestamp for sorting
  let timestamp = Date.now();
  if (date) {
    const parsedDate = Date.parse(date.replace(/at /i, ''));
    if (!isNaN(parsedDate)) {
      timestamp = parsedDate;
    }
  }

  const lowerComb = combinedText.toLowerCase();
  const isCancelled =
    subject.toLowerCase().includes('canceled') ||
    subject.toLowerCase().includes('cancelled') ||
    lowerComb.includes('booking has been canceled') ||
    lowerComb.includes('booking has been cancelled') ||
    lowerComb.includes('has been canceled') ||
    lowerComb.includes('has been cancelled') ||
    lowerComb.includes('was canceled') ||
    lowerComb.includes('was cancelled') ||
    lowerComb.includes('remove this customer from your list');

  return {
    id,
    referenceNumber: referenceNumber || 'GYG-' + id.substring(0, 8),
    tourTitle: tourTitle || 'GetYourGuide Experience',
    fareOption: fareOption || undefined,
    date: date || 'Upcoming',
    timestamp,
    participants: participants || '1 Participant',
    customerName: customerName || 'GetYourGuide Customer',
    customerEmail: customerEmail || '',
    customerPhone: customerPhone || '',
    customerLanguage: customerLanguage || 'English',
    tourLanguage: tourLanguage || 'English',
    pickup: pickup || 'As arranged with provider',
    mapsUrl: mapsUrl || undefined,
    bookingUrl: bookingUrl || undefined,
    imageUrl: imageUrl || undefined,
    price: price || 'Paid',
    priceAmount,
    isReviewBooking,
    isLastMinute,
    receivedAt,
    status: isCancelled ? 'cancelled' : isLastMinute ? 'last-minute' : 'confirmed',
  };
}

function cleanText(text: string): string {
  return text
    .replace(/\[.*?\]\(.*?\)/g, '') // remove markdown links
    .replace(/<[^>]*>/g, '') // remove HTML tags
    .replace(/\s+/g, ' ')
    .trim();
}

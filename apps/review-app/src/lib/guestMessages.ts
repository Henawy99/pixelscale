import { BookingItem, OfferedTour } from '../types';
import { bookingDate, bookingTime } from './dates';
import { platformName } from './finance';

export function firstName(booking: BookingItem): string {
  return (booking.customerName || '').trim().split(/\s+/)[0] ?? '';
}

/** "Salzburg: Private Hallstatt & St. Gilgen Trip" → "Hallstatt & St. Gilgen", for guest messages. */
export function shortTourName(title: string): string {
  const short = title
    .slice(title.lastIndexOf(':') + 1)
    .trim()
    .replace(/^Private\s+/i, '')
    .replace(/\s+(Private\s+)?(Guided\s+)?(Day\s+Trip|Trip|Tour)$/i, '')
    .trim();
  return short || title.trim();
}

/** Sent with the photos taken of the guests on a review booking. */
export function photoThankYouMessage(booking: BookingItem): string {
  const name = firstName(booking);
  const tour = booking.tourTitle ? shortTourName(booking.tourTitle) : '';
  return [
    tour
      ? `Hi ${name || 'there'}, thank you for booking our tour: ${tour}!`
      : `Hi ${name || 'there'}, thank you for travelling with us!`,
    'Here are your photos from the day.',
    `If you enjoyed it, we’d be very grateful for an honest review on ${platformName(booking)}.`,
    'Have a wonderful rest of your trip!',
  ].join(' ');
}

/**
 * The practical points guests need before each GetYourGuide product (by tour id), taken from the
 * listing's inclusions, exclusions and know-before-you-go. The confirmation always starts with the
 * private-tour line, so it isn't repeated here.
 */
const IMPORTANT_INFO: Record<string, string[]> = {
  // Salzburg: Private Hallstatt & St. Gilgen Trip
  '1467727': [
    'The day includes a one-hour stop in St. Gilgen and about 2.5 hours of free time in Hallstatt.',
    'In Hallstatt your driver shows you the best photo spots and agrees a meeting point before you explore.',
    'Optional attraction entrance fees, food and drinks are not included.',
    'Hallstatt has cobbled lanes and some steps, so comfortable walking shoes are recommended.',
    'Infant seats are available on request; just let us know.',
  ],
  // From Salzburg: Hallstatt Heritage & Eagle’s Nest Tour
  '1468371': [
    'The tour crosses into Germany, so every guest needs a valid passport or national ID card.',
    'Eagle’s Nest mountain bus and elevator tickets are included for every guest.',
    'The Eagle’s Nest is open from mid-May to late October and may close in bad weather. If it is closed, you receive a full refund.',
    'Admission to the Documentation Center is optional and not included.',
    'The Eagle’s Nest area has uneven mountain paths, so comfortable shoes are recommended.',
  ],
  // Salzburg: Zell am See & Kitzsteinhorn Private Trip
  '1468375': [
    'Your TOP OF SALZBURG round-trip cable-car ticket to the Kitzsteinhorn (3,029 m) is included.',
    'It is cold at the summit even in summer, so please bring warm clothing, sturdy closed shoes, sunglasses and sunscreen.',
    'The air is thinner at 3,029 metres, so take breaks when you need them.',
    'The mountain visit is self-guided; the cable cars are operated by the official Kitzsteinhorn staff.',
    'The Zell am See boat cruise is optional and not included.',
  ],
  // Salzburg: Hallstatt & Alpine Lakes Private Day Trip
  '1477374': [
    'You have free time at Fuschlsee, St. Gilgen, Hallstatt and Gosausee, with tips and a clear meeting point from your driver at each stop.',
    'Tickets for optional attractions (Bone House, funicular, Skywalk or lake boat), food and drinks are not included.',
    'Hallstatt has cobbled lanes, inclines and some steps, so comfortable shoes are recommended.',
    'Please bring clothing for changing Alpine weather.',
  ],
  // From Salzburg: Hallstatt, Bad Ischl & St. Wolfgang Tour
  '1478630': [
    'You have free time in Hallstatt, Bad Ischl and St. Wolfgang, with tips from your driver.',
    'Optional attractions such as the Kaiservilla or museums are not included and can be paid on site.',
    'Comfortable shoes and weather-appropriate clothing are recommended.',
    'Infant or child seats are available on request; just let us know.',
  ],
  // From Salzburg: Hallstatt Salt Mine & Skywalk Private Tour
  '1478631': [
    'Your round-trip Hallstatt funicular, World Heritage Skywalk and Salt Mine tickets are included.',
    'The Salt Mine ticket has a fixed entry time, which your driver confirms when you arrive in Hallstatt.',
    'From the funicular top station it is about a 15-minute walk, partly uphill, to the mine entrance.',
    'The temperature inside the mine is around 8°C (46°F), so please bring warm clothing and sturdy closed shoes.',
    'The underground tour is guided by the official Salzwelten Hallstatt staff.',
    'Children under 4 cannot enter the Salt Mine.',
  ],
  // From Munich: Salzburg, Hallstatt & Lakes Private Day Trip
  '1482249': [
    'The tour crosses into Austria, so please bring a passport or ID card.',
    'The day lasts about 13 hours, with free time in Salzburg Old Town and Hallstatt and photo stops at Fuschlsee, St. Gilgen and Gosausee.',
    'Optional attraction tickets, food and drinks are not included.',
    'Comfortable walking shoes and clothing for changing Alpine weather are recommended.',
  ],
  // From Salzburg: Private Swarovski, Innsbruck & Nordkette Tour
  '1486364': [
    'Your Swarovski Crystal Worlds admission and Nordkette round-trip funicular and cable-car tickets are included; your driver hands them over.',
    'Nordkette access depends on the weather and cable-car operations. If it is unavailable, you receive a full refund.',
    'Please bring weather-appropriate clothing for the mountain and comfortable shoes for Innsbruck’s cobbled streets.',
    'Lunch is not included; your driver is happy to recommend places in Innsbruck.',
  ],
  // From Salzburg: Multilingual Eagle’s Nest WWII Tour
  '1486803': [
    'The tour enters Germany, so every guest needs a passport or ID card.',
    'Your Eagle’s Nest mountain bus and elevator tickets and Documentation Obersalzberg admission are included.',
    'The Eagle’s Nest is seasonal and weather dependent. If it cannot operate, you receive a full refund.',
    'Please bring a jacket and comfortable shoes.',
    'Lunch and the optional Königssee boat cruise are not included.',
  ],
  // From Linz: Hallstatt & Eagle’s Nest Private Day Trip
  '1487987': [
    'Every guest needs a valid passport or ID card for crossing into Germany.',
    'Your Eagle’s Nest bus and elevator ticket is included.',
    'The day lasts about 10 hours, with about 2.5 hours of free time in Hallstatt. The order of the stops depends on the reserved Eagle’s Nest bus time.',
    'The Eagle’s Nest is seasonal and weather dependent. If it is closed, you can choose a full refund, a new date or an alternative.',
    'Meals and Hallstatt attraction tickets are not included.',
  ],
  // From Linz: Hallstatt, Traunsee & Gosausee Private Day Trip
  '1487990': [
    'You visit Traunsee, Hallstatt and Gosausee; the order of the lake stops may change with traffic and weather.',
    'Walking time at Gosausee depends on the season and the weather.',
    'Boat rides, attraction admissions and meals are not included.',
    'Comfortable shoes and weather-appropriate clothing are recommended.',
  ],
  // From Salzburg: Hallstatt, Red Bull HQ & Attersee Day Trip
  '1488628': [
    'The Red Bull Headquarters stop is from the outside only.',
    'The route order may change because of traffic or weather.',
    'Attraction admissions, food and drinks are not included.',
    'Comfortable shoes and weather-appropriate clothing are recommended.',
  ],
  // From Salzburg: Hallstatt Skywalk & Mondsee Private Tour
  '1488644': [
    'Your round-trip Hallstatt funicular and Skywalk tickets are included; your driver hands them over.',
    'If the funicular or Skywalk is closed for maintenance or weather, you receive a full refund.',
    'Other attraction tickets, food and drinks are not included.',
    'Comfortable shoes and weather-appropriate clothing are recommended.',
  ],
  // From Salzburg: Hallstatt, 5 Fingers & Gosausee Private Tour
  '1488651': [
    'Your Dachstein Krippenstein cable-car tickets for the 5 Fingers platform are included; your driver hands them over.',
    'The 5 Fingers walk involves moderate walking, so please wear comfortable shoes and bring warm, weather-appropriate clothing.',
    'Access depends on the cable car, weather and snow. If it is unavailable, you receive a full refund.',
    'Other attraction tickets, food and drinks are not included.',
  ],
};

const GENERIC_INFO = ['Please wear comfortable shoes and bring clothing for changing Alpine weather.'];

/**
 * The place name from a booking's pickup ("Hotel Sacher Salzburg, Schwarzstraße 5, …" →
 * "Hotel Sacher Salzburg"), or null when the guest hasn't given one yet.
 */
export function pickupPlace(pickup?: string): string | null {
  const text = (pickup || '').trim();
  if (!text || /as arranged/i.test(text)) return null;
  const parts = text.split(',').map((p) => p.trim()).filter(Boolean);
  const name = parts[0]?.length > 3 ? parts[0] : parts.slice(0, 2).join(', ');
  return name || null;
}

/** The confirmation sent to guests of a real tour: private tour, what to know, and the pickup. */
export function confirmationMessage(booking: BookingItem, tour?: OfferedTour | null): string {
  const name = firstName(booking);
  const tourName = booking.tourTitle ? shortTourName(booking.tourTitle) : '';
  const info = [
    'This is a private tour exclusively for you.',
    ...((tour?.gygTourId && IMPORTANT_INFO[tour.gygTourId]) || GENERIC_INFO),
  ];

  const day = bookingDate(booking)?.toLocaleDateString('en-GB', { weekday: 'long', day: 'numeric', month: 'long' });
  const time = bookingTime(booking);
  const when = [day ? `on ${day}` : '', time ? `at ${time}` : ''].filter(Boolean).join(' ');
  const place = pickupPlace(booking.pickup);
  const pickup = place
    ? `Your driver will meet you directly in front of ${place}${when ? ` ${when}` : ''}. Please wait at the main entrance and keep your phone on.`
    : `Please reply with your hotel name or pickup address${tour?.location ? ` in ${tour.location}` : ''} so we can arrange your pickup${when ? ` ${when}` : ''}.`;

  return [
    `Dear ${name || 'Guest'},`,
    '',
    tourName ? `Thanks for booking our ${tourName} tour!` : 'Thanks for your booking!',
    '',
    'Important Information:',
    ...info.map((line) => `• ${line}`),
    '',
    pickup,
    '',
    'We look forward to welcoming you and hope you have a wonderful day with us!',
    'Best regards',
  ].join('\n');
}

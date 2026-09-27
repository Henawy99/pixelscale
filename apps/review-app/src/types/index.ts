export interface TourAnalysis {
  title: string;
  location: string;
  city: string;
  country: string;
  highlights: string[];
  duration: string;
  experienceType: string;
  vibe: string;
  originalUrl: string;
  scrapedImages?: string[];
  description?: string;
}

export type ReviewTone = 'balanced' | 'enthusiastic' | 'casual' | 'detailed' | 'punchy';

export interface ReviewResult {
  text: string;
  rating: number;
  tone: ReviewTone;
  headline?: string;
  authorName?: string;
  tags?: string[];
}

export interface PhotoItem {
  id: string;
  url: string;
  thumbUrl: string;
  alt: string;
  photographer: string;
  photographerUrl?: string;
  source: 'Unsplash' | 'Pexels' | 'Wikimedia' | 'GetYourGuide';
  downloadUrl?: string;
  query: string;
}

export interface AnalyzeRequest {
  url: string;
  tone?: ReviewTone;
  customNotes?: string;
  apiKey?: string;
}

export interface AnalyzeResponse {
  success: boolean;
  tour?: TourAnalysis;
  review?: ReviewResult;
  photos?: PhotoItem[];
  imageQueries?: string[];
  error?: string;
  isDemo?: boolean;
}

export interface HistoryItem {
  id: string;
  timestamp: number;
  tour: TourAnalysis;
  review: ReviewResult;
  photos: PhotoItem[];
}

export interface BookingItem {
  id: string;
  referenceNumber: string;
  tourTitle: string;
  fareOption?: string;
  date: string;
  timestamp?: number;
  participants: string;
  customerName: string;
  customerEmail: string;
  customerPhone: string;
  customerLanguage: string;
  tourLanguage: string;
  pickup: string;
  mapsUrl?: string;
  bookingUrl?: string;
  imageUrl?: string;
  price: string;
  priceAmount?: number;
  isReviewBooking?: boolean;
  isLastMinute: boolean;
  receivedAt: string;
  status: 'confirmed' | 'last-minute' | 'cancelled' | 'pending';
  platform?: 'getyourguide' | 'airbnb' | 'viator' | 'other';
  grossPrice?: string;
  /** Supplier product reference code (e.g. "HALL-5F-GOSAU"), when the booking email carries it. */
  productReference?: string;
  /** GetYourGuide product id (e.g. "1478631"), when the booking email carries it. */
  gygTourId?: string;
}

export function getNumericPrice(b: BookingItem): number {
  if (typeof b.priceAmount === 'number' && !isNaN(b.priceAmount)) return b.priceAmount;
  const num = parseFloat((b.price || '').replace(/[^0-9.,]/g, '').replace(',', '.'));
  return isNaN(num) ? 0 : num;
}

/** Commission kept by the booking platform: 20% on Airbnb, 30% on GetYourGuide. */
export function platformFeeRate(b: BookingItem): number {
  return b.platform === 'airbnb' ? 0.2 : 0.3;
}

export function isBookingReview(b: BookingItem): boolean {
  if (b.isReviewBooking === true) return true;
  const price = getNumericPrice(b);
  if (price > 0 && price < 30) return true;
  const title = (b.tourTitle || '').toLowerCase();
  const fare = (b.fareOption || '').toLowerCase();
  if (title.includes('review') || fare.includes('review')) return true;
  return false;
}

export interface ZohoConfig {
  email: string;
  password?: string;
  host?: string;
  port?: number;
  folder?: string;
  forceRefresh?: boolean;
}

export interface GmailConfig {
  email: string;
  password?: string;
  host?: string;
  port?: number;
  folder?: string;
  forceRefresh?: boolean;
}

export interface BookingsResponse {
  success: boolean;
  bookings: BookingItem[];
  total: number;
  source: 'zoho' | 'gmail' | 'multi' | 'mock' | 'cache';
  lastSyncedAt: string;
  error?: string;
  account?: string;
  zohoStatus?: string;
  gmailStatus?: string;
}

export interface Driver {
  id: string;
  name: string;
  phone: string;
  payoutType: 'percentage' | 'fixed'; // percentage of net GYG payout (e.g. 50%) or fixed EUR per tour (e.g. €120)
  defaultPayoutRate: number; // e.g. 50 (%) or 120 (EUR)
  color?: string;
  notes?: string;
  createdAt: number;
}

export interface DriverAssignment {
  bookingRef: string;
  driverId: string;
  assignedAt: number;
  customPayoutAmount?: number; // Optional override for this specific tour
}

export interface Reviewer {
  id: string;
  name: string;
  phone: string; // WhatsApp phone number, e.g. +43 664 1234567
  whatsappPhone?: string; // alias for phone
  color?: string;
  notes?: string;
  createdAt: number;
}

export interface ReviewerAssignment {
  bookingRef: string;
  reviewerId: string;
  assignedAt: number;
  reviewText?: string;
  generatedReviewText?: string; // alias
  photoUrls?: string[];
  notes?: string;
}

/** An entrance or transport ticket bought for every guest of a tour, e.g. the Salt Mine combo. */
export interface TourTicket {
  id: string;
  name: string;
  /** EUR per guest; 0 means the price hasn't been entered yet. */
  pricePerPassenger: number;
}

/** A product in the GetYourGuide supplier catalog. */
export interface OfferedTour {
  id: string;
  title: string;
  gygUrl: string;
  /** Supplier "Product Reference Code", e.g. "HALL-5F-GOSAU". */
  referenceCode?: string;
  /** Numeric GetYourGuide product id from the URL, e.g. "1478631". */
  gygTourId?: string;
  /** Older or alternate titles that booking emails may still use. */
  aliases?: string[];
  tickets?: TourTicket[];
  location?: string;
  notes?: string;
  createdAt: number;
}

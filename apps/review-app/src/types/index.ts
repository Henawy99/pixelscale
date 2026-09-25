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
}

export interface ZohoConfig {
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
  source: 'zoho' | 'mock' | 'cache';
  lastSyncedAt: string;
  error?: string;
  account?: string;
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

export interface TourTicketRule {
  id: string;
  tourKeyword: string; // e.g. "Hallstatt Salt Mine" or "Hallstatt"
  tourNamePattern?: string; // Human label e.g. "Hallstatt Salt Mine & Skywalk Private Tour"
  ticketCostPerPassenger: number; // e.g. 49 (EUR)
  fixedBookingCost?: number; // optional fixed booking fee (e.g. reservation fee)
  description?: string;
  isEnabled: boolean;
  createdAt: number;
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

export type ActiveTab = 'bookings' | 'calendar' | 'drivers' | 'studio' | 'settings' | 'history';
export type FilterType = 'all' | 'normal' | 'review' | 'confirmed' | 'last-minute' | 'cancelled';



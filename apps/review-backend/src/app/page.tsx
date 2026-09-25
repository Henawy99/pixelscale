'use client';

import React, { useState, useEffect, useRef, useCallback } from 'react';
import {
  Sparkles,
  Compass,
  AlertCircle,
  Bell,
  X,
} from 'lucide-react';
import confetti from 'canvas-confetti';
import { Navbar } from '@/components/Navbar';
import { BottomNav, ActiveTab } from '@/components/BottomNav';
import { BookingsFeed } from '@/components/BookingsFeed';
import { TourForm } from '@/components/TourForm';
import { LoadingSteps } from '@/components/LoadingSteps';
import { ReviewDisplay } from '@/components/ReviewDisplay';
import { PhotoGallery } from '@/components/PhotoGallery';
import { TourDetailsCard } from '@/components/TourDetailsCard';
import { HistoryDrawer } from '@/components/HistoryDrawer';
import { SettingsModal } from '@/components/SettingsModal';
import {
  AnalyzeResponse,
  BookingItem,
  HistoryItem,
  ReviewTone,
  ZohoConfig,
  BookingsResponse,
} from '@/lib/types';

export default function Home() {
  const [activeTab, setActiveTab] = useState<ActiveTab>('bookings');

  // Generator state
  const [isLoading, setIsLoading] = useState(false);
  const [isLoadingRegen, setIsLoadingRegen] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [currentResult, setCurrentResult] = useState<AnalyzeResponse | null>(null);
  const [, setCurrentTone] = useState<ReviewTone>('balanced');
  const [lastSubmittedUrl, setLastSubmittedUrl] = useState<string>('');
  const [prefilledUrl, setPrefilledUrl] = useState<string>('');
  const [prefilledNotes, setPrefilledNotes] = useState<string>('');

  // Modals & Storage state
  const [isSettingsOpen, setIsSettingsOpen] = useState(false);
  const [isHistoryOpen, setIsHistoryOpen] = useState(false);
  const [customGeminiKey, setCustomGeminiKey] = useState<string>('');
  const [history, setHistory] = useState<HistoryItem[]>([]);

  // Bookings & Zoho state
  const [bookings, setBookings] = useState<BookingItem[]>([]);
  const [isLoadingBookings, setIsLoadingBookings] = useState(true);
  const [isSyncingBookings, setIsSyncingBookings] = useState(false);
  const [isServerZohoConnected, setIsServerZohoConnected] = useState(true);
  const [lastSyncedAt, setLastSyncedAt] = useState<string>('');
  const [syncError, setSyncError] = useState<string | null>(null);
  const [zohoConfig, setZohoConfig] = useState<ZohoConfig>({
    email: '',
    password: '',
    host: 'imappro.zoho.eu',
    port: 993,
  });
  const [newBookingAlert, setNewBookingAlert] = useState<BookingItem | null>(null);

  const resultsRef = useRef<HTMLDivElement>(null);
  const generatorTopRef = useRef<HTMLDivElement>(null);

  // Initialize from localStorage asynchronously to prevent cascading renders
  useEffect(() => {
    const timer = setTimeout(() => {
      try {
        const storedKey = localStorage.getItem('review_app_gemini_key') || '';
        if (storedKey) setCustomGeminiKey(storedKey);

        const storedHistory = localStorage.getItem('review_app_history');
        if (storedHistory) {
          setHistory(JSON.parse(storedHistory));
        }

        const storedZoho = localStorage.getItem('review_app_zoho_config');
        if (storedZoho) {
          const parsed = JSON.parse(storedZoho);
          setZohoConfig(parsed);
        }
      } catch {
        // LocalStorage unavailable
      }
    }, 0);
    return () => clearTimeout(timer);
  }, []);

  const isZohoConnected = Boolean((zohoConfig.email && zohoConfig.password) || isServerZohoConnected);

  // Fetch bookings function
  const fetchBookings = useCallback(
    async (showMainSpinner = false) => {
      if (showMainSpinner) {
        setIsLoadingBookings(true);
      } else {
        setIsSyncingBookings(true);
      }
      setSyncError(null);

      try {
        const headers: Record<string, string> = {};
        if (zohoConfig.email) {
          headers['x-zoho-email'] = zohoConfig.email;
          if (zohoConfig.password) headers['x-zoho-password'] = zohoConfig.password;
          if (zohoConfig.host) headers['x-zoho-host'] = zohoConfig.host;
        }

        const res = await fetch('/api/bookings', { headers });
        const data: BookingsResponse = await res.json();

        if (data.source === 'zoho') {
          setIsServerZohoConnected(true);
        } else if (data.source === 'mock' && !zohoConfig.email) {
          setIsServerZohoConnected(false);
        }

        if (data.success && Array.isArray(data.bookings)) {
          // Check for new bookings to notify
          setBookings((prev) => {
            const prevIds = new Set(prev.map((b) => b.referenceNumber));
            const freshOnes = data.bookings.filter((b) => !prevIds.has(b.referenceNumber));
            if (freshOnes.length > 0 && prev.length > 0) {
              setNewBookingAlert(freshOnes[0]);
              try {
                confetti({
                  particleCount: 40,
                  spread: 60,
                  origin: { y: 0.2 },
                });
              } catch {
                // ignore
              }
            }
            return data.bookings;
          });
          setLastSyncedAt(data.lastSyncedAt || new Date().toISOString());
        }

        if (data.error) {
          setSyncError(data.error);
        }
      } catch (err: unknown) {
        const msg = err instanceof Error ? err.message : 'Failed to fetch bookings';
        setSyncError(msg);
      } finally {
        setIsLoadingBookings(false);
        setIsSyncingBookings(false);
      }
    },
    [zohoConfig]
  );

  // Initial fetch and auto-sync
  useEffect(() => {
    const initialTimer = setTimeout(() => {
      fetchBookings(false);
    }, 50);

    const intervalTimer = setInterval(() => {
      fetchBookings(false);
    }, 45000);

    return () => {
      clearTimeout(initialTimer);
      clearInterval(intervalTimer);
    };
  }, [fetchBookings]);

  const handleSaveGeminiKey = (key: string) => {
    setCustomGeminiKey(key);
    try {
      if (key) {
        localStorage.setItem('review_app_gemini_key', key);
      } else {
        localStorage.removeItem('review_app_gemini_key');
      }
    } catch {
      // LocalStorage error
    }
  };

  const handleSaveZohoConfig = (cfg: ZohoConfig) => {
    setZohoConfig(cfg);
    try {
      localStorage.setItem('review_app_zoho_config', JSON.stringify(cfg));
    } catch {
      // LocalStorage error
    }
    // Re-fetch with new config
    setTimeout(() => {
      fetchBookings(true);
    }, 100);
  };

  const saveToHistory = (data: AnalyzeResponse) => {
    if (!data.tour || !data.review || !data.photos) return;
    const newItem: HistoryItem = {
      id: `${Date.now()}-${Math.random().toString(36).substring(2, 9)}`,
      timestamp: Date.now(),
      tour: data.tour,
      review: data.review,
      photos: data.photos,
    };

    const updated = [newItem, ...history.filter((h) => h.tour.title !== data.tour?.title)].slice(0, 20);
    setHistory(updated);
    try {
      localStorage.setItem('review_app_history', JSON.stringify(updated));
    } catch {
      // ignore
    }
  };

  const handleClearHistory = () => {
    setHistory([]);
    try {
      localStorage.removeItem('review_app_history');
    } catch {
      // ignore
    }
  };

  const handleDeleteHistoryItem = (id: string) => {
    const updated = history.filter((h) => h.id !== id);
    setHistory(updated);
    try {
      localStorage.setItem('review_app_history', JSON.stringify(updated));
    } catch {
      // ignore
    }
  };

  const handleSelectHistoryItem = (item: HistoryItem) => {
    setCurrentResult({
      success: true,
      tour: item.tour,
      review: item.review,
      photos: item.photos,
      imageQueries: [],
    });
    setLastSubmittedUrl(item.tour.originalUrl);
    setActiveTab('generator');
    setTimeout(() => {
      resultsRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  };

  // Flow from Bookings -> Generate Review
  const handleSelectBookingForReview = (booking: BookingItem) => {
    // Set pre-filled info
    setPrefilledUrl(booking.tourTitle);
    setPrefilledNotes(
      `Booking ${booking.referenceNumber} | Customer: ${booking.customerName} (${booking.customerLanguage}) | Option: ${booking.fareOption || 'Standard'} | Pickup: ${booking.pickup}`
    );
    // Switch to generator tab
    setActiveTab('generator');
    // Scroll to top
    setTimeout(() => {
      generatorTopRef.current?.scrollIntoView({ behavior: 'smooth' });
    }, 100);
  };

  const handleGenerate = async (
    url: string,
    tone: ReviewTone,
    customNotes: string
  ) => {
    setIsLoading(true);
    setError(null);
    setCurrentTone(tone);
    setLastSubmittedUrl(url);

    try {
      const res = await fetch('/api/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(customGeminiKey ? { 'x-gemini-key': customGeminiKey } : {}),
        },
        body: JSON.stringify({
          url,
          tone,
          customNotes,
          apiKey: customGeminiKey || undefined,
        }),
      });

      const data: AnalyzeResponse = await res.json();

      if (!res.ok || !data.success) {
        throw new Error(data.error || 'Failed to analyze tour');
      }

      setCurrentResult(data);
      saveToHistory(data);

      // Trigger Confetti Celebration
      try {
        confetti({
          particleCount: 70,
          spread: 70,
          origin: { y: 0.6 },
          colors: ['#6366f1', '#f43f5e', '#f59e0b', '#10b981'],
        });
      } catch {
        // ignore
      }

      // Smooth scroll to output
      setTimeout(() => {
        resultsRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
      }, 200);
    } catch (err: unknown) {
      const msg = err instanceof Error ? err.message : 'An error occurred while generating the review';
      setError(msg);
    } finally {
      setIsLoading(false);
    }
  };

  const handleRegenerateTone = async (newTone: ReviewTone) => {
    if (!lastSubmittedUrl || isLoadingRegen) return;
    setIsLoadingRegen(true);
    setCurrentTone(newTone);

    try {
      const res = await fetch('/api/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          ...(customGeminiKey ? { 'x-gemini-key': customGeminiKey } : {}),
        },
        body: JSON.stringify({
          url: lastSubmittedUrl,
          tone: newTone,
          apiKey: customGeminiKey || undefined,
        }),
      });

      const data: AnalyzeResponse = await res.json();
      if (data.success && data.review) {
        setCurrentResult((prev) =>
          prev
            ? {
                ...prev,
                review: data.review,
                ...(data.photos ? { photos: data.photos } : {}),
              }
            : data
        );
      }
    } catch (e) {
      console.error('Tone regen error:', e);
    } finally {
      setIsLoadingRegen(false);
    }
  };

  const hasLastMinute = bookings.some((b) => b.isLastMinute);

  return (
    <div className="min-h-screen flex flex-col bg-slate-50 text-slate-900 relative overflow-x-hidden selection:bg-indigo-100 selection:text-indigo-900">
      {/* Background ambient radial spotlights */}
      <div className="fixed top-0 left-1/2 -translate-x-1/2 w-[600px] h-[350px] bg-gradient-to-b from-indigo-100/70 via-violet-50/40 to-transparent rounded-full blur-3xl pointer-events-none -z-10" />
      <div className="fixed bottom-20 -right-40 w-[400px] h-[400px] bg-amber-100/60 rounded-full blur-3xl pointer-events-none -z-10" />

      {/* Top Header / Navbar */}
      <Navbar
        onOpenSettings={() => setIsSettingsOpen(true)}
        onOpenHistory={() => setIsHistoryOpen(true)}
        historyCount={history.length}
        hasCustomKey={Boolean(customGeminiKey)}
        isZohoConnected={isZohoConnected}
        isSyncing={isSyncingBookings}
        onSyncBookings={() => fetchBookings(false)}
      />

      {/* New Booking Live Toast Notification */}
      {newBookingAlert && (
        <div className="fixed top-16 inset-x-4 max-w-md mx-auto z-50 animate-in slide-in-from-top-3 duration-300">
          <div className="p-3.5 rounded-2xl bg-gradient-to-r from-amber-600 to-rose-600 text-white shadow-2xl flex items-center justify-between gap-3 border border-white/20">
            <div className="flex items-center gap-2.5 min-w-0">
              <div className="p-1.5 rounded-xl bg-white/20 shrink-0">
                <Bell className="h-4 w-4 text-white animate-bounce" />
              </div>
              <div className="min-w-0">
                <p className="text-xs font-bold leading-tight truncate">
                  New GYG Booking: {newBookingAlert.referenceNumber}
                </p>
                <p className="text-[11px] text-white/90 truncate">
                  {newBookingAlert.customerName} • {newBookingAlert.tourTitle}
                </p>
              </div>
            </div>
            <div className="flex items-center gap-1.5 shrink-0">
              <button
                type="button"
                onClick={() => {
                  handleSelectBookingForReview(newBookingAlert);
                  setNewBookingAlert(null);
                }}
                className="px-2.5 py-1 rounded-lg bg-white text-slate-950 font-bold text-xs hover:bg-slate-100 transition-colors shadow-sm"
              >
                Review
              </button>
              <button
                type="button"
                onClick={() => setNewBookingAlert(null)}
                className="p-1 rounded-lg hover:bg-white/20 text-white/80 hover:text-white"
              >
                <X className="h-4 w-4" />
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Main Content Container - Mobile View Optimized */}
      <main className="flex-1 w-full max-w-md mx-auto px-3.5 pt-3 pb-24 flex flex-col">
        {/* TAB 1: BOOKINGS FEED */}
        {activeTab === 'bookings' && (
          <div className="w-full animate-in fade-in duration-200">
            <BookingsFeed
              bookings={bookings}
              isLoading={isLoadingBookings}
              isSyncing={isSyncingBookings}
              onRefresh={() => fetchBookings(false)}
              onSelectForReview={handleSelectBookingForReview}
              onOpenSettings={() => setIsSettingsOpen(true)}
              isZohoConnected={isZohoConnected}
              lastSyncedAt={lastSyncedAt}
              syncError={syncError}
            />
          </div>
        )}

        {/* TAB 2: GENERATE REVIEW STUDIO */}
        {activeTab === 'generator' && (
          <div ref={generatorTopRef} className="w-full space-y-5 animate-in fade-in duration-200">
            {/* Form */}
            <TourForm
              onSubmit={handleGenerate}
              isLoading={isLoading}
              initialUrl={prefilledUrl}
              initialNotes={prefilledNotes}
            />

            {/* Error Banner */}
            {error && (
              <div className="w-full p-3.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-800 flex items-start gap-2.5 shadow-sm animate-in fade-in duration-200">
                <AlertCircle className="h-4 w-4 text-rose-500 shrink-0 mt-0.5" />
                <div className="flex-1 text-xs">
                  <h4 className="font-semibold text-rose-900">Unable to generate review</h4>
                  <p className="text-rose-700 mt-0.5">{error}</p>
                </div>
                <button
                  type="button"
                  onClick={() => setError(null)}
                  className="text-xs text-rose-500 hover:text-rose-800"
                >
                  <X className="h-4 w-4" />
                </button>
              </div>
            )}

            {/* Loading Progress Feedback */}
            {isLoading && <LoadingSteps />}

            {/* Results Section */}
            {currentResult && !isLoading && (
              <div
                ref={resultsRef}
                className="w-full space-y-5 pt-2 animate-in fade-in slide-in-from-bottom-4 duration-300"
              >
                {/* Demo Mode Notice if applicable */}
                {currentResult.isDemo && (
                  <div className="p-3 rounded-xl bg-indigo-50 border border-indigo-200 text-indigo-800 flex items-center justify-between gap-2 text-xs">
                    <div className="flex items-center gap-1.5">
                      <Sparkles className="h-4 w-4 text-indigo-600 shrink-0" />
                      <span>Gemini demo mode. Add free API key for custom generation.</span>
                    </div>
                    <button
                      type="button"
                      onClick={() => setIsSettingsOpen(true)}
                      className="px-2.5 py-1 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white font-medium shrink-0 transition-colors text-[11px]"
                    >
                      Key
                    </button>
                  </div>
                )}

                {/* Extracted Tour Intelligence */}
                {currentResult.tour && <TourDetailsCard tour={currentResult.tour} />}

                {/* Generated Traveler Review Card */}
                {currentResult.review && (
                  <div>
                    <div className="flex items-center justify-between mb-2 px-1">
                      <h3 className="text-base font-bold text-slate-900 flex items-center gap-1.5">
                        <Sparkles className="h-4 w-4 text-amber-500" />
                        <span>Traveler Review</span>
                      </h3>
                      <span className="text-[11px] text-slate-500">
                        Ready to copy
                      </span>
                    </div>
                    <ReviewDisplay
                      review={currentResult.review}
                      onRegenerateTone={handleRegenerateTone}
                      isLoadingRegen={isLoadingRegen}
                    />
                  </div>
                )}

                {/* 3 Photos Grid */}
                {currentResult.photos && currentResult.photos.length > 0 && (
                  <div className="pt-2">
                    <PhotoGallery
                      photos={currentResult.photos}
                      tourTitle={currentResult.tour?.title}
                    />
                  </div>
                )}
              </div>
            )}

            {/* Empty State / Tips when no review generated yet */}
            {!currentResult && !isLoading && (
              <div className="p-4 rounded-2xl bg-white border border-slate-200/80 shadow-sm space-y-3 text-xs text-slate-600">
                <div className="flex items-center gap-2 text-slate-900 font-semibold">
                  <Compass className="h-4 w-4 text-indigo-600" />
                  <span>Tip: Quick Review from Bookings</span>
                </div>
                <p className="leading-relaxed text-[11px]">
                  Switch to the <strong className="text-slate-900">Bookings tab</strong> to see incoming GetYourGuide reservations. Tap <strong className="text-indigo-600">&ldquo;Generate Review&rdquo;</strong> on any booking to generate an authentic traveler review and photos in 1 tap!
                </p>
              </div>
            )}
          </div>
        )}
      </main>

      {/* Fixed Mobile Bottom Navigation Bar */}
      <BottomNav
        activeTab={activeTab}
        onTabChange={setActiveTab}
        bookingCount={bookings.length}
        hasLastMinute={hasLastMinute}
        onOpenSettings={() => setIsSettingsOpen(true)}
        onOpenHistory={() => setIsHistoryOpen(true)}
        onSyncBookings={() => fetchBookings(false)}
        isSyncing={isSyncingBookings}
      />

      {/* Modals & Drawers */}
      <SettingsModal
        isOpen={isSettingsOpen}
        onClose={() => setIsSettingsOpen(false)}
        geminiKey={customGeminiKey}
        onSaveGeminiKey={handleSaveGeminiKey}
        zohoConfig={zohoConfig}
        onSaveZohoConfig={handleSaveZohoConfig}
      />

      <HistoryDrawer
        isOpen={isHistoryOpen}
        onClose={() => setIsHistoryOpen(false)}
        items={history}
        onSelect={handleSelectHistoryItem}
        onClear={handleClearHistory}
        onDeleteOne={handleDeleteHistoryItem}
      />
    </div>
  );
}

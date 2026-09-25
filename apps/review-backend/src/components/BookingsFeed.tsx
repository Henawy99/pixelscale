'use client';

import React, { useState, useMemo } from 'react';
import {
  Calendar,
  MapPin,
  User,
  Phone,
  Mail,
  Copy,
  Check,
  ExternalLink,
  Sparkles,
  RefreshCw,
  Search,
  Flame,
  Tag,
  AlertCircle,
  CheckCircle2,
  TrendingUp,
  Wallet,
  Briefcase,
  Star,
  ChevronDown,
  Percent,
} from 'lucide-react';
import { BookingItem } from '@/lib/types';

interface BookingsFeedProps {
  bookings: BookingItem[];
  isLoading: boolean;
  isSyncing: boolean;
  onRefresh: () => void;
  onSelectForReview: (booking: BookingItem) => void;
  onOpenSettings: () => void;
  isZohoConnected: boolean;
  lastSyncedAt?: string;
  syncError?: string | null;
}

type FilterType = 'all' | 'normal' | 'review' | 'confirmed' | 'last-minute' | 'cancelled';

function getNumericPrice(booking: BookingItem): number {
  if (typeof booking.priceAmount === 'number') return booking.priceAmount;
  const num = parseFloat((booking.price || '').replace(/[^0-9.,]/g, '').replace(',', '.'));
  return isNaN(num) ? 0 : num;
}

function isBookingReview(booking: BookingItem): boolean {
  if (typeof booking.isReviewBooking === 'boolean') return booking.isReviewBooking;
  const price = getNumericPrice(booking);
  return price > 0 && price < 30;
}

function getMonthYear(booking: BookingItem): string {
  if (booking.date && booking.date !== 'Upcoming') {
    const match = booking.date.match(/([A-Za-z]+)\s+\d{1,2},\s+(\d{4})/);
    if (match) return `${match[1]} ${match[2]}`;
  }
  if (booking.timestamp) {
    const d = new Date(booking.timestamp);
    return d.toLocaleString('en-US', { month: 'long', year: 'numeric' });
  }
  return 'Other';
}

export function BookingsFeed({
  bookings,
  isLoading,
  isSyncing,
  onRefresh,
  onSelectForReview,
  onOpenSettings,
  isZohoConnected,
  lastSyncedAt,
  syncError,
}: BookingsFeedProps) {
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedFilter, setSelectedFilter] = useState<FilterType>('all');
  const [copiedId, setCopiedId] = useState<string | null>(null);

  // Group revenue by month
  const monthlyStats = useMemo(() => {
    const map: Record<
      string,
      {
        totalRevenue: number;
        normalRevenue: number;
        reviewRevenue: number;
        normalCount: number;
        reviewCount: number;
        totalCount: number;
      }
    > = {};

    bookings.forEach((b) => {
      // Exclude cancelled bookings from revenue calculations
      if (b.status === 'cancelled') return;

      const my = getMonthYear(b);
      if (!map[my]) {
        map[my] = {
          totalRevenue: 0,
          normalRevenue: 0,
          reviewRevenue: 0,
          normalCount: 0,
          reviewCount: 0,
          totalCount: 0,
        };
      }

      const price = getNumericPrice(b);
      const isReview = isBookingReview(b);

      map[my].totalRevenue += price;
      map[my].totalCount++;
      if (isReview) {
        map[my].reviewRevenue += price;
        map[my].reviewCount++;
      } else {
        map[my].normalRevenue += price;
        map[my].normalCount++;
      }
    });

    return map;
  }, [bookings]);

  const availableMonths = useMemo(() => {
    const months = Object.keys(monthlyStats);
    // Sort so September 2026 is at the top if present
    return months.sort((a, b) => {
      if (a.includes('September')) return -1;
      if (b.includes('September')) return 1;
      return a.localeCompare(b);
    });
  }, [monthlyStats]);

  const [selectedMonth, setSelectedMonth] = useState<string>('September 2026');

  // Active revenue figures for the selected month or all
  const activeRevenueStats = useMemo(() => {
    if (selectedMonth === 'All Time') {
      let totalRevenue = 0;
      let normalRevenue = 0;
      let reviewRevenue = 0;
      let normalCount = 0;
      let reviewCount = 0;
      let totalCount = 0;

      Object.values(monthlyStats).forEach((s) => {
        totalRevenue += s.totalRevenue;
        normalRevenue += s.normalRevenue;
        reviewRevenue += s.reviewRevenue;
        normalCount += s.normalCount;
        reviewCount += s.reviewCount;
        totalCount += s.totalCount;
      });

      return { totalRevenue, normalRevenue, reviewRevenue, normalCount, reviewCount, totalCount };
    }

    return (
      monthlyStats[selectedMonth] || {
        totalRevenue: 0,
        normalRevenue: 0,
        reviewRevenue: 0,
        normalCount: 0,
        reviewCount: 0,
        totalCount: 0,
      }
    );
  }, [monthlyStats, selectedMonth]);

  const handleCopyRef = (ref: string, e: React.MouseEvent) => {
    e.stopPropagation();
    navigator.clipboard.writeText(ref);
    setCopiedId(ref);
    setTimeout(() => setCopiedId(null), 1800);
  };

  const filteredBookings = useMemo(() => {
    return bookings.filter((item) => {
      const isReview = isBookingReview(item);

      // Filter tab
      if (selectedFilter === 'normal' && (isReview || item.status === 'cancelled')) return false;
      if (selectedFilter === 'review' && (!isReview || item.status === 'cancelled')) return false;
      if (selectedFilter === 'last-minute' && (!item.isLastMinute || item.status === 'cancelled')) return false;
      if (selectedFilter === 'confirmed' && item.status !== 'confirmed') return false;
      if (selectedFilter === 'cancelled' && item.status !== 'cancelled') return false;

      // Search query
      if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        const matchesRef = item.referenceNumber.toLowerCase().includes(q);
        const matchesTitle = item.tourTitle.toLowerCase().includes(q);
        const matchesCustomer = item.customerName.toLowerCase().includes(q);
        const matchesPhone = item.customerPhone.toLowerCase().includes(q);
        const matchesPickup = item.pickup.toLowerCase().includes(q);
        const matchesPrice = item.price.toLowerCase().includes(q);
        return matchesRef || matchesTitle || matchesCustomer || matchesPhone || matchesPickup || matchesPrice;
      }
      return true;
    });
  }, [bookings, selectedFilter, searchQuery]);

  // Counts for pills
  const normalCount = useMemo(() => {
    return bookings.filter((b) => !isBookingReview(b) && b.status !== 'cancelled').length;
  }, [bookings]);

  const reviewCount = useMemo(() => {
    return bookings.filter((b) => isBookingReview(b) && b.status !== 'cancelled').length;
  }, [bookings]);

  const lastMinuteCount = useMemo(() => {
    return bookings.filter((b) => b.isLastMinute && b.status !== 'cancelled').length;
  }, [bookings]);

  const confirmedCount = useMemo(() => {
    return bookings.filter((b) => b.status === 'confirmed').length;
  }, [bookings]);

  const cancelledCount = useMemo(() => {
    return bookings.filter((b) => b.status === 'cancelled').length;
  }, [bookings]);

  const formattedSyncTime = useMemo(() => {
    if (!lastSyncedAt) return 'Just now';
    try {
      const d = new Date(lastSyncedAt);
      return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    } catch {
      return 'Recently';
    }
  }, [lastSyncedAt]);

  return (
    <div className="w-full space-y-4 pb-6">
      {/* 1. MONTHLY REVENUE KPI CARD */}
      <div className="rounded-2xl bg-gradient-to-br from-indigo-900 via-indigo-800 to-slate-900 text-white p-4 shadow-lg shadow-indigo-950/20 border border-indigo-700/40 relative overflow-hidden">
        {/* Ambient background glow inside card */}
        <div className="absolute top-0 right-0 w-48 h-48 bg-emerald-500/10 rounded-full blur-2xl pointer-events-none" />
        <div className="absolute bottom-0 left-0 w-36 h-36 bg-indigo-500/20 rounded-full blur-xl pointer-events-none" />

        <div className="relative z-10 space-y-3">
          {/* Card Header: Title & Month Picker */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <div className="p-1.5 rounded-lg bg-white/10 text-emerald-300">
                <Wallet className="h-4 w-4" />
              </div>
              <div>
                <span className="text-xs uppercase tracking-wider font-bold text-indigo-200">
                  Monthly Revenue & Net Payout
                </span>
                <p className="text-[10px] text-indigo-300/80">30% GetYourGuide commission applied</p>
              </div>
            </div>

            {/* Month Dropdown Selector */}
            <div className="relative">
              <select
                value={selectedMonth}
                onChange={(e) => setSelectedMonth(e.target.value)}
                className="appearance-none bg-white/15 hover:bg-white/20 border border-white/20 text-white text-xs font-semibold py-1 pl-2.5 pr-7 rounded-xl focus:outline-none cursor-pointer transition-colors"
              >
                {availableMonths.map((m) => (
                  <option key={m} value={m} className="bg-slate-900 text-white">
                    {m}
                  </option>
                ))}
                <option value="All Time" className="bg-slate-900 text-white">
                  All Time
                </option>
              </select>
              <ChevronDown className="absolute right-2 top-1/2 -translate-y-1/2 h-3.5 w-3.5 text-white/70 pointer-events-none" />
            </div>
          </div>

          {/* Revenue & Commission Breakdown */}
          <div className="pt-1 space-y-2.5">
            {/* Primary Net Payout (70%) */}
            <div>
              <span className="text-[11px] font-semibold text-emerald-300 uppercase tracking-wider flex items-center gap-1">
                <span>Estimated Net Payout (70%)</span>
              </span>
              <div className="flex items-baseline gap-2">
                <span className="text-3xl font-black tracking-tight text-white">
                  € {(activeRevenueStats.totalRevenue * 0.7).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
                <span className="text-xs font-semibold text-emerald-400 bg-emerald-500/20 px-2 py-0.5 rounded-full flex items-center gap-1 border border-emerald-500/30">
                  <TrendingUp className="h-3 w-3" />
                  <span>{activeRevenueStats.totalCount} active bookings</span>
                </span>
              </div>
            </div>

            {/* Gross Revenue vs 30% GYG Fee Strip */}
            <div className="grid grid-cols-2 gap-2 text-xs">
              <div className="px-2.5 py-1.5 rounded-xl bg-white/10 border border-white/10">
                <span className="text-indigo-200 text-[10px] block font-medium">Customer Paid (Gross)</span>
                <span className="text-sm font-bold text-white">
                  € {activeRevenueStats.totalRevenue.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
              <div className="px-2.5 py-1.5 rounded-xl bg-rose-500/15 border border-rose-400/20 text-rose-200">
                <span className="text-rose-300 text-[10px] block font-medium flex items-center gap-1">
                  <Percent className="h-2.5 w-2.5" />
                  <span>GYG Comm. (30%)</span>
                </span>
                <span className="text-sm font-bold text-rose-300">
                  -€ {(activeRevenueStats.totalRevenue * 0.3).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </span>
              </div>
            </div>
          </div>

          {/* Two-Column Breakdown (Normal vs Review) */}
          <div className="grid grid-cols-2 gap-2 pt-1">
            {/* Normal Tours */}
            <div className="p-2.5 rounded-xl bg-white/10 backdrop-blur-sm border border-white/10 space-y-1">
              <div className="flex items-center justify-between text-[11px] font-semibold text-indigo-200">
                <div className="flex items-center gap-1">
                  <Briefcase className="h-3.5 w-3.5 text-blue-300" />
                  <span>Normal Tours</span>
                </div>
                <span className="text-[10px] text-indigo-300/80">≥€30</span>
              </div>
              <div>
                <p className="text-base font-bold text-white leading-tight">
                  € {(activeRevenueStats.normalRevenue * 0.7).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  <span className="text-[10px] font-semibold text-emerald-300 ml-1">net</span>
                </p>
                <p className="text-[10px] text-indigo-200/80">
                  Gross: € {activeRevenueStats.normalRevenue.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
                <p className="text-[10px] text-rose-300/90 font-medium">
                  30% fee: -€ {(activeRevenueStats.normalRevenue * 0.3).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
              <p className="text-[10px] text-indigo-300/70 pt-0.5 border-t border-white/10">
                {activeRevenueStats.normalCount} tour{activeRevenueStats.normalCount === 1 ? '' : 's'}
              </p>
            </div>

            {/* Review Bookings (<€30) */}
            <div className="p-2.5 rounded-xl bg-white/10 backdrop-blur-sm border border-white/10 space-y-1">
              <div className="flex items-center justify-between text-[11px] font-semibold text-amber-200">
                <div className="flex items-center gap-1">
                  <Star className="h-3.5 w-3.5 text-amber-300 fill-amber-300" />
                  <span>Review Bookings</span>
                </div>
                <span className="text-[10px] text-amber-200/80">&lt;€30</span>
              </div>
              <div>
                <p className="text-base font-bold text-white leading-tight">
                  € {(activeRevenueStats.reviewRevenue * 0.7).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                  <span className="text-[10px] font-semibold text-amber-300 ml-1">net</span>
                </p>
                <p className="text-[10px] text-amber-200/80">
                  Gross: € {activeRevenueStats.reviewRevenue.toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
                <p className="text-[10px] text-rose-300/90 font-medium">
                  30% fee: -€ {(activeRevenueStats.reviewRevenue * 0.3).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                </p>
              </div>
              <p className="text-[10px] text-amber-200/70 pt-0.5 border-t border-white/10">
                {activeRevenueStats.reviewCount} booking{activeRevenueStats.reviewCount === 1 ? '' : 's'}
              </p>
            </div>
          </div>
        </div>
      </div>

      {/* 2. TOP HEADER & SEARCH CARD (LIGHT THEME) */}
      <div className="rounded-2xl bg-white border border-slate-200 p-4 shadow-sm">
        <div className="flex items-center justify-between mb-3">
          <div>
            <div className="flex items-center gap-2">
              <h2 className="text-lg font-extrabold text-slate-900 tracking-tight">
                GetYourGuide Bookings
              </h2>
              <span className="px-2 py-0.5 rounded-full text-[11px] font-bold bg-indigo-50 text-indigo-700 border border-indigo-100">
                {bookings.length}
              </span>
            </div>
            <p className="text-xs text-slate-500 mt-0.5 flex items-center gap-1.5">
              <span>Synced with Zoho:</span>
              <span className="text-slate-700 font-semibold">{formattedSyncTime}</span>
            </p>
          </div>

          {/* Sync action button */}
          <button
            type="button"
            onClick={onRefresh}
            disabled={isSyncing}
            className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold border border-slate-200 shadow-sm transition-all active:scale-95 disabled:opacity-50"
          >
            <RefreshCw className={`h-3.5 w-3.5 ${isSyncing ? 'animate-spin text-amber-600' : 'text-slate-600'}`} />
            <span>{isSyncing ? 'Syncing...' : 'Sync'}</span>
          </button>
        </div>

        {/* Zoho Connection Banner */}
        {!isZohoConnected ? (
          <div className="mt-2 p-3 rounded-xl bg-amber-50 border border-amber-200 flex items-start gap-2.5">
            <AlertCircle className="h-4 w-4 text-amber-600 shrink-0 mt-0.5" />
            <div className="flex-1 text-xs">
              <p className="text-amber-900 font-medium">
                Showing sample GYG bookings (Demo Mode)
              </p>
              <p className="text-amber-700 text-[11px] mt-0.5">
                Connect your Zoho Mail in Settings to automatically fetch live GetYourGuide booking emails.
              </p>
            </div>
            <button
              type="button"
              onClick={onOpenSettings}
              className="px-2.5 py-1 rounded-lg bg-amber-600 hover:bg-amber-700 text-white font-bold text-[11px] transition-colors shrink-0"
            >
              Connect
            </button>
          </div>
        ) : (
          <div className="mt-2 p-2.5 rounded-xl bg-emerald-50 border border-emerald-200 flex items-center justify-between text-xs">
            <div className="flex items-center gap-2 text-emerald-800 font-medium">
              <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
              <span>Live Zoho IMAP Active</span>
            </div>
            <span className="text-[11px] text-emerald-700">Auto-refresh 45s</span>
          </div>
        )}

        {syncError && (
          <div className="mt-2 p-2.5 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-[11px] flex items-center gap-2">
            <AlertCircle className="h-4 w-4 text-rose-500 shrink-0" />
            <span className="flex-1 truncate">{syncError}</span>
          </div>
        )}

        {/* Search Bar */}
        <div className="relative mt-3">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-slate-400" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search booking ref, customer, tour, or price..."
            className="w-full pl-9 pr-4 py-2 rounded-xl bg-slate-50 border border-slate-200 text-slate-900 placeholder-slate-400 text-xs focus:outline-none focus:border-indigo-500 focus:bg-white focus:ring-1 focus:ring-indigo-500 transition-colors"
          />
        </div>

        {/* Filter Pills with "Review Bookings" and "Normal Bookings" */}
        <div className="flex items-center gap-1.5 mt-3 overflow-x-auto no-scrollbar pb-1">
          {/* All */}
          <button
            type="button"
            onClick={() => setSelectedFilter('all')}
            className={`px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${
              selectedFilter === 'all'
                ? 'bg-indigo-600 text-white shadow-sm'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            All ({bookings.length})
          </button>

          {/* Normal Bookings (>=30€) */}
          <button
            type="button"
            onClick={() => setSelectedFilter('normal')}
            className={`flex items-center gap-1 px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${
              selectedFilter === 'normal'
                ? 'bg-blue-600 text-white shadow-sm'
                : 'bg-blue-50 text-blue-700 hover:bg-blue-100 border border-blue-200/60'
            }`}
          >
            <Briefcase className="h-3 w-3" />
            <span>Normal ({normalCount})</span>
          </button>

          {/* Review Bookings (<30€) */}
          <button
            type="button"
            onClick={() => setSelectedFilter('review')}
            className={`flex items-center gap-1 px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${
              selectedFilter === 'review'
                ? 'bg-violet-600 text-white shadow-sm'
                : 'bg-violet-50 text-violet-700 hover:bg-violet-100 border border-violet-200/60'
            }`}
          >
            <Star className="h-3 w-3 fill-violet-400 text-violet-400" />
            <span>Reviews ({reviewCount})</span>
          </button>

          {/* Confirmed */}
          <button
            type="button"
            onClick={() => setSelectedFilter('confirmed')}
            className={`flex items-center gap-1 px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${
              selectedFilter === 'confirmed'
                ? 'bg-emerald-600 text-white shadow-sm'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            <CheckCircle2 className="h-3 w-3" />
            <span>Confirmed ({confirmedCount})</span>
          </button>

          {/* Last-Minute */}
          <button
            type="button"
            onClick={() => setSelectedFilter('last-minute')}
            className={`flex items-center gap-1 px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${
              selectedFilter === 'last-minute'
                ? 'bg-amber-600 text-white shadow-sm'
                : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
            }`}
          >
            <Flame className="h-3 w-3 text-amber-500" />
            <span>Last-Minute ({lastMinuteCount})</span>
          </button>

          {/* Cancelled */}
          {cancelledCount > 0 && (
            <button
              type="button"
              onClick={() => setSelectedFilter('cancelled')}
              className={`flex items-center gap-1 px-3 py-1 rounded-lg text-xs font-semibold whitespace-nowrap transition-all ${
                selectedFilter === 'cancelled'
                  ? 'bg-rose-600 text-white shadow-sm'
                  : 'bg-rose-50 text-rose-700 hover:bg-rose-100 border border-rose-200/60'
              }`}
            >
              <AlertCircle className="h-3 w-3 text-rose-500" />
              <span>Cancelled ({cancelledCount})</span>
            </button>
          )}
        </div>
      </div>

      {/* Loading Skeletons */}
      {isLoading && (
        <div className="space-y-3">
          {[1, 2].map((i) => (
            <div
              key={i}
              className="p-4 rounded-2xl bg-white border border-slate-200 animate-pulse space-y-3 shadow-sm"
            >
              <div className="flex justify-between">
                <div className="h-4 w-28 bg-slate-200 rounded-md" />
                <div className="h-4 w-20 bg-slate-200 rounded-md" />
              </div>
              <div className="h-5 w-3/4 bg-slate-200 rounded-md" />
              <div className="h-14 bg-slate-100 rounded-xl" />
            </div>
          ))}
        </div>
      )}

      {/* Empty State */}
      {!isLoading && filteredBookings.length === 0 && (
        <div className="text-center py-12 px-4 rounded-2xl bg-white border border-dashed border-slate-300 shadow-sm">
          <Calendar className="h-10 w-10 text-slate-400 mx-auto mb-3 opacity-60" />
          <h3 className="text-base font-bold text-slate-900">No bookings match filter</h3>
          <p className="text-xs text-slate-500 mt-1 max-w-xs mx-auto">
            {searchQuery
              ? 'Try adjusting your search query or clear the filter.'
              : 'Try selecting a different filter above.'}
          </p>
          {(searchQuery || selectedFilter !== 'all') && (
            <button
              type="button"
              onClick={() => {
                setSearchQuery('');
                setSelectedFilter('all');
              }}
              className="mt-3 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-xs font-semibold text-slate-700 transition-colors"
            >
              Reset Filters
            </button>
          )}
        </div>
      )}

      {/* 3. BOOKINGS LIST (LIGHT THEME CARDS) */}
      {!isLoading && (
        <div className="space-y-3.5">
          {filteredBookings.map((booking) => {
            const isCopied = copiedId === booking.referenceNumber;
            const isCancelled = booking.status === 'cancelled';
            const isReview = isBookingReview(booking);

            return (
              <div
                key={booking.id}
                className={`relative rounded-2xl border transition-all duration-200 overflow-hidden shadow-sm hover:shadow-md ${
                  isCancelled
                    ? 'bg-white border-rose-200 opacity-80'
                    : isReview
                    ? 'bg-white border-violet-200/90'
                    : booking.isLastMinute
                    ? 'bg-white border-amber-300'
                    : 'bg-white border-slate-200'
                }`}
              >
                {/* Top Badge Strip */}
                <div className="px-4 py-2.5 bg-slate-50 border-b border-slate-100 flex items-center justify-between text-xs gap-1.5 flex-wrap">
                  {/* Left: Reference Number with 1-click Copy */}
                  <div className="flex items-center gap-1.5">
                    <span className="text-[11px] font-semibold text-slate-500 uppercase tracking-wider">
                      Ref:
                    </span>
                    <button
                      type="button"
                      onClick={(e) => handleCopyRef(booking.referenceNumber, e)}
                      title="Click to copy reference code"
                      className="group flex items-center gap-1 px-2 py-0.5 rounded-md bg-white hover:bg-slate-100 border border-slate-200 font-mono font-bold text-slate-800 text-xs transition-colors"
                    >
                      <span>{booking.referenceNumber}</span>
                      {isCopied ? (
                        <Check className="h-3 w-3 text-emerald-600" />
                      ) : (
                        <Copy className="h-3 w-3 text-slate-400 group-hover:text-slate-700" />
                      )}
                    </button>
                    {isCopied && (
                      <span className="text-[10px] text-emerald-600 font-bold">Copied!</span>
                    )}
                  </div>

                  {/* Right: Badges (Review Booking / Normal + Status) */}
                  <div className="flex items-center gap-1.5">
                    {/* Review Booking Badge vs Normal */}
                    {isReview ? (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-violet-50 text-violet-700 border border-violet-200">
                        <Star className="h-2.5 w-2.5 fill-violet-600 text-violet-600" />
                        <span>Review Booking</span>
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold uppercase tracking-wider bg-blue-50 text-blue-700 border border-blue-200">
                        <Briefcase className="h-2.5 w-2.5 text-blue-600" />
                        <span>Normal Tour</span>
                      </span>
                    )}

                    {/* Status Badge */}
                    {isCancelled ? (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-rose-50 text-rose-700 border border-rose-200">
                        <AlertCircle className="h-2.5 w-2.5 text-rose-500" />
                        <span>Cancelled</span>
                      </span>
                    ) : booking.isLastMinute ? (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider bg-amber-50 text-amber-700 border border-amber-200">
                        <Flame className="h-2.5 w-2.5 fill-amber-500 text-amber-500" />
                        <span>Last-Minute</span>
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-semibold uppercase tracking-wider bg-emerald-50 text-emerald-700 border border-emerald-200">
                        <CheckCircle2 className="h-2.5 w-2.5 text-emerald-600" />
                        <span>Confirmed</span>
                      </span>
                    )}
                  </div>
                </div>

                {/* Main Card Body */}
                <div className="p-4 space-y-3.5">
                  {/* Tour Title & Option */}
                  <div>
                    <h3 className="text-base font-bold text-slate-900 leading-snug tracking-tight">
                      {booking.tourTitle}
                    </h3>
                    {booking.fareOption && (
                      <p className="text-xs text-indigo-700 font-medium mt-0.5 flex items-center gap-1">
                        <Tag className="h-3 w-3 shrink-0 text-indigo-500" />
                        <span>{booking.fareOption}</span>
                      </p>
                    )}
                  </div>

                  {/* Highlights Grid (Date & Price) */}
                  <div className="grid grid-cols-2 gap-2 text-xs">
                    {/* Date & Time */}
                    <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100 space-y-0.5">
                      <span className="text-[10px] uppercase font-semibold text-slate-500 flex items-center gap-1">
                        <Calendar className="h-3 w-3 text-indigo-500" />
                        <span>Date & Time</span>
                      </span>
                      <p className="text-xs font-bold text-slate-900 truncate">
                        {booking.date}
                      </p>
                    </div>

                    {/* Participants & Price with 30% GYG fee calculation */}
                    <div className="p-2.5 rounded-xl bg-slate-50 border border-slate-100 space-y-1">
                      <div className="flex items-center justify-between text-[10px] uppercase font-semibold text-slate-500">
                        <span className="flex items-center gap-1">
                          <User className="h-3 w-3 text-amber-600" />
                          <span>Party & Payout</span>
                        </span>
                        <span className="text-[10px] font-medium text-slate-400">30% GYG fee</span>
                      </div>
                      <div className="flex items-baseline justify-between gap-1">
                        <p className="text-xs font-bold text-slate-900 truncate">
                          {booking.participants} • <span className="font-extrabold text-slate-900">{booking.price}</span>
                        </p>
                        {getNumericPrice(booking) > 0 && (
                          <span className="text-[11px] font-extrabold text-emerald-600 shrink-0 bg-emerald-50 px-1.5 py-0.5 rounded border border-emerald-200/60">
                            Net: € {(getNumericPrice(booking) * 0.7).toLocaleString('de-DE', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}
                          </span>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Customer Information Card */}
                  <div className="p-3 rounded-xl bg-slate-50 border border-slate-100 space-y-2">
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <div className="w-7 h-7 rounded-full bg-gradient-to-tr from-indigo-600 to-violet-600 flex items-center justify-center text-xs font-bold text-white shadow-sm">
                          {booking.customerName.charAt(0) || 'G'}
                        </div>
                        <div>
                          <p className="text-xs font-bold text-slate-900 leading-tight">
                            {booking.customerName}
                          </p>
                          <p className="text-[10px] text-slate-500">
                            Language: {booking.customerLanguage} • Tour: {booking.tourLanguage}
                          </p>
                        </div>
                      </div>
                    </div>

                    {/* Action buttons: Phone & Email */}
                    <div className="flex items-center gap-2 pt-1 border-t border-slate-200/60">
                      {booking.customerPhone && (
                        <a
                          href={`tel:${booking.customerPhone}`}
                          className="flex-1 inline-flex items-center justify-center gap-1.5 py-1.5 px-2 rounded-lg bg-white hover:bg-slate-100 text-slate-700 text-xs font-semibold border border-slate-200 transition-colors shadow-2xs"
                        >
                          <Phone className="h-3.5 w-3.5 text-emerald-600" />
                          <span className="truncate">{booking.customerPhone}</span>
                        </a>
                      )}
                      {booking.customerEmail && (
                        <a
                          href={`mailto:${booking.customerEmail}`}
                          className="flex-1 inline-flex items-center justify-center gap-1.5 py-1.5 px-2 rounded-lg bg-white hover:bg-slate-100 text-slate-700 text-xs font-semibold border border-slate-200 transition-colors shadow-2xs"
                        >
                          <Mail className="h-3.5 w-3.5 text-indigo-600" />
                          <span>Email</span>
                        </a>
                      )}
                    </div>
                  </div>

                  {/* Pickup Location */}
                  {booking.pickup && (
                    <div className="flex items-start justify-between gap-2 p-2.5 rounded-xl bg-slate-50 border border-slate-100 text-xs">
                      <div className="flex items-start gap-1.5 flex-1 min-w-0">
                        <MapPin className="h-3.5 w-3.5 text-rose-500 shrink-0 mt-0.5" />
                        <div>
                          <span className="text-[10px] uppercase font-semibold text-slate-500 block">
                            Pickup Point
                          </span>
                          <span className="text-xs text-slate-700 font-medium leading-snug line-clamp-2">
                            {booking.pickup}
                          </span>
                        </div>
                      </div>
                      {booking.mapsUrl && (
                        <a
                          href={booking.mapsUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="px-2 py-1 rounded-lg bg-indigo-50 hover:bg-indigo-100 border border-indigo-200 text-indigo-700 text-[11px] font-semibold shrink-0 inline-flex items-center gap-1 transition-colors"
                        >
                          <span>Maps</span>
                          <ExternalLink className="h-3 w-3" />
                        </a>
                      )}
                    </div>
                  )}

                  {/* Primary Action Buttons */}
                  <div className="pt-1 flex items-center gap-2">
                    {/* 1-Tap Generate Review */}
                    <button
                      type="button"
                      onClick={() => onSelectForReview(booking)}
                      className="flex-1 inline-flex items-center justify-center gap-2 py-2.5 px-3 rounded-xl bg-gradient-to-r from-indigo-600 to-violet-600 hover:from-indigo-700 hover:to-violet-700 text-white text-xs font-bold shadow-md shadow-indigo-200 active:scale-[0.98] transition-all cursor-pointer"
                    >
                      <Sparkles className="h-4 w-4 text-amber-300" />
                      <span>Generate Review</span>
                    </button>

                    {/* GYG Link if available */}
                    {booking.bookingUrl && (
                      <a
                        href={booking.bookingUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="p-2.5 rounded-xl bg-slate-100 hover:bg-slate-200 text-slate-600 hover:text-slate-900 border border-slate-200 transition-colors"
                        title="Open in GetYourGuide Supplier Portal"
                      >
                        <ExternalLink className="h-4 w-4" />
                      </a>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}

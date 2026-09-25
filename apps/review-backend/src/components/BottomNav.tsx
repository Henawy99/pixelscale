'use client';

import React from 'react';
import { Sparkles, CalendarCheck2, History, Settings2, RefreshCw } from 'lucide-react';

export type ActiveTab = 'generator' | 'bookings';

interface BottomNavProps {
  activeTab: ActiveTab;
  onTabChange: (tab: ActiveTab) => void;
  bookingCount: number;
  hasLastMinute?: boolean;
  onOpenSettings: () => void;
  onOpenHistory: () => void;
  onSyncBookings?: () => void;
  isSyncing?: boolean;
}

export function BottomNav({
  activeTab,
  onTabChange,
  bookingCount,
  hasLastMinute = false,
  onOpenSettings,
  onOpenHistory,
  onSyncBookings,
  isSyncing = false,
}: BottomNavProps) {
  return (
    <nav
      aria-label="Bottom Navigation"
      className="fixed bottom-0 inset-x-0 z-40 pointer-events-none"
    >
      <div className="max-w-md mx-auto px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] pt-2 pointer-events-auto">
        <div className="relative flex items-center justify-around px-2 py-2 rounded-2xl bg-white/95 backdrop-blur-xl border border-slate-200 shadow-xl shadow-slate-200/80">
          {/* Tab 1: Generate Review */}
          <button
            type="button"
            onClick={() => onTabChange('generator')}
            className={`relative flex flex-col items-center justify-center flex-1 py-1.5 px-2 rounded-xl transition-all duration-200 active:scale-95 ${
              activeTab === 'generator'
                ? 'text-indigo-600 font-bold'
                : 'text-slate-500 hover:text-slate-800 font-medium'
            }`}
          >
            {activeTab === 'generator' && (
              <span className="absolute -top-1.5 inset-x-4 h-0.5 bg-gradient-to-r from-transparent via-indigo-600 to-transparent rounded-full" />
            )}
            <div className={`p-1 rounded-lg transition-colors ${
              activeTab === 'generator' ? 'bg-indigo-50 text-indigo-600' : ''
            }`}>
              <Sparkles className="h-5 w-5" />
            </div>
            <span className="text-[11px] mt-0.5 tracking-tight">Review Studio</span>
          </button>

          {/* Tab 2: Bookings (with notification badge) */}
          <button
            type="button"
            onClick={() => onTabChange('bookings')}
            className={`relative flex flex-col items-center justify-center flex-1 py-1.5 px-2 rounded-xl transition-all duration-200 active:scale-95 ${
              activeTab === 'bookings'
                ? 'text-indigo-600 font-bold'
                : 'text-slate-500 hover:text-slate-800 font-medium'
            }`}
          >
            {activeTab === 'bookings' && (
              <span className="absolute -top-1.5 inset-x-4 h-0.5 bg-gradient-to-r from-transparent via-indigo-600 to-transparent rounded-full" />
            )}
            <div className="relative">
              <div className={`p-1 rounded-lg transition-colors ${
                activeTab === 'bookings' ? 'bg-indigo-50 text-indigo-600' : ''
              }`}>
                <CalendarCheck2 className="h-5 w-5" />
              </div>
              {/* Badge indicator */}
              {bookingCount > 0 && (
                <span className={`absolute -top-1 -right-2 min-w-4 h-4 px-1 flex items-center justify-center text-[10px] font-bold rounded-full text-white shadow-sm ${
                  hasLastMinute ? 'bg-rose-500 animate-pulse' : 'bg-indigo-600'
                }`}>
                  {bookingCount}
                </span>
              )}
            </div>
            <span className="text-[11px] mt-0.5 tracking-tight flex items-center gap-1">
              Bookings
              {hasLastMinute && (
                <span className="w-1.5 h-1.5 rounded-full bg-rose-500 animate-ping inline-block" />
              )}
            </span>
          </button>

          {/* Tab 3: Quick Sync */}
          {onSyncBookings && (
            <button
              type="button"
              onClick={onSyncBookings}
              disabled={isSyncing}
              title="Sync Zoho Mail"
              className="flex flex-col items-center justify-center py-1.5 px-2.5 rounded-xl text-slate-500 hover:text-slate-800 transition-all duration-200 active:scale-95 disabled:opacity-50"
            >
              <div className="p-1 rounded-lg">
                <RefreshCw className={`h-5 w-5 ${isSyncing ? 'animate-spin text-amber-600' : ''}`} />
              </div>
              <span className="text-[11px] mt-0.5 tracking-tight">Sync</span>
            </button>
          )}

          {/* Tab 4: History */}
          <button
            type="button"
            onClick={onOpenHistory}
            className="flex flex-col items-center justify-center py-1.5 px-2.5 rounded-xl text-slate-500 hover:text-slate-800 transition-all duration-200 active:scale-95"
          >
            <div className="p-1 rounded-lg">
              <History className="h-5 w-5" />
            </div>
            <span className="text-[11px] mt-0.5 tracking-tight">History</span>
          </button>

          {/* Tab 5: Settings */}
          <button
            type="button"
            onClick={onOpenSettings}
            className="flex flex-col items-center justify-center py-1.5 px-2.5 rounded-xl text-slate-500 hover:text-slate-800 transition-all duration-200 active:scale-95"
          >
            <div className="p-1 rounded-lg">
              <Settings2 className="h-5 w-5" />
            </div>
            <span className="text-[11px] mt-0.5 tracking-tight">Settings</span>
          </button>
        </div>
      </div>
    </nav>
  );
}

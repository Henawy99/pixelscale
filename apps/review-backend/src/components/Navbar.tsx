'use client';

import React from 'react';
import { Compass, RefreshCw, Settings } from 'lucide-react';

interface NavbarProps {
  onOpenSettings: () => void;
  onOpenHistory: () => void;
  historyCount: number;
  hasCustomKey: boolean;
  isZohoConnected: boolean;
  isSyncing?: boolean;
  onSyncBookings?: () => void;
}

export function Navbar({
  onOpenSettings,
  isZohoConnected,
  isSyncing = false,
  onSyncBookings,
}: NavbarProps) {
  return (
    <header className="sticky top-0 z-40 w-full border-b border-slate-200/80 bg-white/90 backdrop-blur-xl">
      <div className="max-w-md mx-auto px-4 h-14 flex items-center justify-between">
        {/* Brand & Identity */}
        <div className="flex items-center gap-2.5">
          <div className="h-8 w-8 rounded-xl bg-gradient-to-tr from-amber-500 via-rose-500 to-indigo-600 flex items-center justify-center shadow-sm shadow-indigo-500/20 ring-1 ring-slate-200/80">
            <Compass className="h-4 w-4 text-white" />
          </div>
          <div>
            <div className="flex items-center gap-1.5">
              <span className="font-extrabold text-sm tracking-tight text-slate-900">PixelReview</span>
              <span className="px-1.5 py-0.5 rounded text-[10px] font-bold bg-indigo-50 text-indigo-700 border border-indigo-200">
                GYG
              </span>
            </div>
          </div>
        </div>

        {/* Status Chip & Quick Actions */}
        <div className="flex items-center gap-2">
          {/* Zoho Status Pill */}
          <button
            type="button"
            onClick={onOpenSettings}
            className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-[11px] font-medium border transition-colors ${
              isZohoConnected
                ? 'bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100/70'
                : 'bg-amber-50 text-amber-700 border-amber-200 hover:bg-amber-100/70'
            }`}
            title={isZohoConnected ? 'Zoho Mail Connected' : 'Demo Mode - Click to connect Zoho'}
          >
            <span
              className={`w-1.5 h-1.5 rounded-full ${
                isZohoConnected ? 'bg-emerald-500 animate-pulse' : 'bg-amber-500'
              }`}
            />
            <span className="font-semibold">{isZohoConnected ? 'Zoho Live' : 'Demo Mode'}</span>
          </button>

          {/* Quick Sync */}
          {onSyncBookings && (
            <button
              type="button"
              onClick={onSyncBookings}
              disabled={isSyncing}
              className="p-1.5 rounded-lg text-slate-600 hover:text-slate-900 hover:bg-slate-100 border border-slate-200 transition-colors disabled:opacity-50"
              title="Sync Zoho Mail"
            >
              <RefreshCw className={`h-4 w-4 ${isSyncing ? 'animate-spin text-amber-600' : ''}`} />
            </button>
          )}

          {/* Settings Shortcut */}
          <button
            type="button"
            onClick={onOpenSettings}
            className="p-1.5 rounded-lg text-slate-600 hover:text-slate-900 hover:bg-slate-100 border border-slate-200 transition-colors"
            title="Settings"
          >
            <Settings className="h-4 w-4" />
          </button>
        </div>
      </div>
    </header>
  );
}

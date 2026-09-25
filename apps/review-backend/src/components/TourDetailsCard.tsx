'use client';

import React, { useState } from 'react';
import {
  MapPin,
  Clock,
  Compass,
  Sparkles,
  ExternalLink,
  ChevronDown,
  ChevronUp,
  CheckCircle,
} from 'lucide-react';
import { TourAnalysis } from '@/lib/types';

interface TourDetailsCardProps {
  tour: TourAnalysis;
}

export function TourDetailsCard({ tour }: TourDetailsCardProps) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div className="w-full rounded-2xl bg-white border border-slate-200 p-5 sm:p-6 shadow-sm">
      {/* Title & Location Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 pb-4 border-b border-slate-100">
        <div>
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-wider text-indigo-600 mb-1">
            <Sparkles className="h-3.5 w-3.5" />
            <span>Extracted Tour Intelligence</span>
          </div>
          <h2 className="text-xl sm:text-2xl font-extrabold text-slate-900 tracking-tight">
            {tour.title}
          </h2>
          <div className="flex items-center gap-1.5 text-sm text-slate-600 mt-1">
            <MapPin className="h-4 w-4 text-rose-500 shrink-0" />
            <span>{tour.location || tour.city || 'Global Destination'}</span>
          </div>
        </div>

        {/* View on GetYourGuide link */}
        {tour.originalUrl && (
          <a
            href={tour.originalUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-semibold text-slate-700 hover:text-slate-900 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-colors shrink-0 self-start sm:self-auto shadow-2xs"
          >
            <span>View on GetYourGuide</span>
            <ExternalLink className="h-3.5 w-3.5" />
          </a>
        )}
      </div>

      {/* Quick Pills */}
      <div className="grid grid-cols-2 sm:grid-cols-3 gap-3 py-4 border-b border-slate-100 text-xs">
        <div className="flex items-center gap-2 p-2.5 rounded-xl bg-slate-50 border border-slate-100">
          <Clock className="h-4 w-4 text-amber-500 shrink-0" />
          <div>
            <span className="text-[10px] text-slate-500 block uppercase font-medium">Duration</span>
            <span className="font-bold text-slate-900">{tour.duration || '2-3 Hours'}</span>
          </div>
        </div>

        <div className="flex items-center gap-2 p-2.5 rounded-xl bg-slate-50 border border-slate-100">
          <Compass className="h-4 w-4 text-indigo-500 shrink-0" />
          <div>
            <span className="text-[10px] text-slate-500 block uppercase font-medium">Experience Type</span>
            <span className="font-bold text-slate-900 truncate">{tour.experienceType || 'Guided Tour'}</span>
          </div>
        </div>

        <div className="col-span-2 sm:col-span-1 flex items-center gap-2 p-2.5 rounded-xl bg-slate-50 border border-slate-100">
          <Sparkles className="h-4 w-4 text-rose-500 shrink-0" />
          <div>
            <span className="text-[10px] text-slate-500 block uppercase font-medium">Vibe</span>
            <span className="font-bold text-slate-900 truncate">{tour.vibe || 'Captivating'}</span>
          </div>
        </div>
      </div>

      {/* Highlights Section */}
      <div className="pt-4">
        <div className="flex items-center justify-between mb-3">
          <h4 className="text-xs font-bold uppercase tracking-wider text-slate-500">
            Tour Highlights & Sights
          </h4>
          {tour.highlights.length > 3 && (
            <button
              onClick={() => setIsExpanded(!isExpanded)}
              className="text-xs text-indigo-600 hover:text-indigo-700 font-semibold inline-flex items-center gap-1"
            >
              <span>{isExpanded ? 'Show Less' : `View All (${tour.highlights.length})`}</span>
              {isExpanded ? <ChevronUp className="h-3 w-3" /> : <ChevronDown className="h-3 w-3" />}
            </button>
          )}
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 text-xs text-slate-800">
          {(isExpanded ? tour.highlights : tour.highlights.slice(0, 4)).map((item, idx) => (
            <div
              key={idx}
              className="flex items-start gap-2 p-2 rounded-lg bg-indigo-50/60 border border-indigo-100/80 leading-relaxed font-medium"
            >
              <CheckCircle className="h-3.5 w-3.5 text-indigo-600 shrink-0 mt-0.5" />
              <span>{item}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

'use client';

import React, { useState } from 'react';
import {
  Link2,
  Sparkles,
  X,
  AlertCircle,
  SlidersHorizontal,
  ChevronDown,
  ChevronUp,
} from 'lucide-react';
import { ReviewTone } from '@/lib/types';

interface TourFormProps {
  onSubmit: (url: string, tone: ReviewTone, customNotes: string) => void;
  isLoading: boolean;
  initialUrl?: string;
  initialNotes?: string;
}

const SAMPLE_TOURS = [
  {
    name: 'Colosseum Underground, Rome',
    city: 'Rome, Italy',
    url: 'https://www.getyourguide.com/rome-l33/colosseum-underground-and-ancient-rome-tour-t412217/',
  },
  {
    name: 'Grand Canal Gondola, Venice',
    city: 'Venice, Italy',
    url: 'https://www.getyourguide.com/venice-l35/grand-canal-gondola-ride-with-live-commentary-t394851/',
  },
  {
    name: 'Schönbrunn Palace, Vienna',
    city: 'Vienna, Austria',
    url: 'https://www.getyourguide.com/vienna-l29/vienna-schonbrunn-palace-gardens-tour-skip-the-line-t402832/',
  },
  {
    name: 'Eiffel Tower & Cruise, Paris',
    city: 'Paris, France',
    url: 'https://www.getyourguide.com/paris-l16/paris-eiffel-tower-summit-access-and-seine-river-cruise-t401128/',
  },
];

const TONES: { id: ReviewTone; label: string; desc: string }[] = [
  { id: 'balanced', label: 'Balanced', desc: 'Warm, natural & authentic' },
  { id: 'enthusiastic', label: 'Enthusiastic', desc: 'Excited & high-energy' },
  { id: 'casual', label: 'Casual', desc: 'Relaxed & conversational' },
  { id: 'detailed', label: 'Detailed', desc: 'Observant with tips & pacing' },
  { id: 'punchy', label: 'Punchy', desc: 'Short, impactful 3 sentences' },
];

export function TourForm({
  onSubmit,
  isLoading,
  initialUrl = '',
  initialNotes = '',
}: TourFormProps) {
  const [url, setUrl] = useState(initialUrl);
  const [tone, setTone] = useState<ReviewTone>('balanced');
  const [customNotes, setCustomNotes] = useState(initialNotes);
  const [showOptions, setShowOptions] = useState(false);
  const [validationError, setValidationError] = useState<string | null>(null);

  const [prevInitialUrl, setPrevInitialUrl] = useState(initialUrl);
  const [prevInitialNotes, setPrevInitialNotes] = useState(initialNotes);

  if (initialUrl !== prevInitialUrl) {
    setPrevInitialUrl(initialUrl);
    setUrl(initialUrl);
    setValidationError(null);
  }

  if (initialNotes !== prevInitialNotes) {
    setPrevInitialNotes(initialNotes);
    setCustomNotes(initialNotes);
    setShowOptions(true);
  }

  const validateUrl = (testUrl: string): boolean => {
    if (!testUrl.trim()) {
      setValidationError('Please enter a tour URL or tour title');
      return false;
    }
    const lower = testUrl.toLowerCase();
    if (lower.startsWith('http') && !lower.includes('getyourguide.')) {
      setValidationError('Please provide a valid GetYourGuide link (must contain getyourguide.com)');
      return false;
    }
    setValidationError(null);
    return true;
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const val = e.target.value;
    setUrl(val);
    if (validationError && val.trim()) {
      validateUrl(val);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (validateUrl(url)) {
      let finalUrl = url.trim();
      // If user typed a tour title instead of full URL, convert to GYG search link
      if (!finalUrl.startsWith('http')) {
        finalUrl = `https://www.getyourguide.com/s/?q=${encodeURIComponent(finalUrl)}`;
      }
      onSubmit(finalUrl, tone, customNotes.trim());
    }
  };

  const selectSample = (sampleUrl: string) => {
    setUrl(sampleUrl);
    setValidationError(null);
  };

  return (
    <div className="w-full max-w-4xl mx-auto">
      {/* Hero Headings */}
      <div className="text-center mb-8 sm:mb-10">
        <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-indigo-50 border border-indigo-200/80 text-xs font-semibold text-indigo-700 mb-4">
          <Sparkles className="h-3.5 w-3.5 text-amber-500" />
          <span>AI-Powered Traveler Review & Visuals Studio</span>
        </div>
        <h1 className="text-3xl sm:text-5xl lg:text-6xl font-extrabold tracking-tight text-slate-900 mb-4">
          Turn Tour Links into{' '}
          <span className="text-transparent bg-clip-text bg-gradient-to-r from-amber-600 via-rose-600 to-indigo-600">
            Authentic Reviews
          </span>
        </h1>
        <p className="text-base sm:text-lg text-slate-600 max-w-2xl mx-auto leading-relaxed">
          Paste any GetYourGuide tour link. Gemini analyzes highlights, writes a realistic
          first-person traveler review, and sources 3 matching high-res photos.
        </p>
      </div>

      {/* Main Input Form */}
      <form onSubmit={handleSubmit} className="relative z-10">
        <div className="p-2 sm:p-2.5 rounded-2xl bg-white border border-slate-200 shadow-md backdrop-blur-xl transition-all focus-within:border-indigo-500 focus-within:ring-2 focus-within:ring-indigo-100">
          <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-2">
            {/* Input Field */}
            <div className="relative flex-1 flex items-center">
              <Link2 className="absolute left-4 h-5 w-5 text-slate-400 pointer-events-none" />
              <input
                type="text"
                value={url}
                onChange={handleInputChange}
                placeholder="Paste your GetYourGuide tour link here…"
                disabled={isLoading}
                className="w-full pl-12 pr-10 py-3.5 sm:py-4 bg-transparent text-slate-900 placeholder-slate-400 text-sm sm:text-base focus:outline-none disabled:opacity-50"
              />
              {url && !isLoading && (
                <button
                  type="button"
                  onClick={() => {
                    setUrl('');
                    setValidationError(null);
                  }}
                  className="absolute right-3 p-1.5 rounded-lg text-slate-400 hover:text-slate-700 hover:bg-slate-100 transition-colors"
                >
                  <X className="h-4 w-4" />
                </button>
              )}
            </div>

            {/* Primary Action Button */}
            <button
              type="submit"
              disabled={isLoading || !url.trim()}
              className="relative inline-flex items-center justify-center gap-2 px-7 py-3.5 sm:py-4 rounded-xl font-semibold text-white bg-gradient-to-r from-indigo-600 via-indigo-500 to-rose-600 hover:from-indigo-500 hover:via-indigo-400 hover:to-rose-500 shadow-md shadow-indigo-200 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-none whitespace-nowrap group"
            >
              <Sparkles className="h-5 w-5 text-indigo-100 transition-transform group-hover:rotate-12" />
              <span>{isLoading ? 'Analyzing Tour…' : 'Generate Review'}</span>
            </button>
          </div>

          {/* Validation Error Message */}
          {validationError && (
            <div className="px-4 py-2.5 mt-2 flex items-center gap-2 rounded-lg bg-rose-50 border border-rose-200 text-rose-700 text-sm animate-in fade-in duration-200">
              <AlertCircle className="h-4 w-4 shrink-0 text-rose-500" />
              <span>{validationError}</span>
            </div>
          )}
        </div>

        {/* Quick Sample Links */}
        <div className="mt-4 flex flex-wrap items-center gap-2 px-1 text-xs">
          <span className="text-slate-500 font-medium">Try with sample:</span>
          {SAMPLE_TOURS.map((sample) => (
            <button
              key={sample.name}
              type="button"
              onClick={() => selectSample(sample.url)}
              disabled={isLoading}
              className="px-2.5 py-1 rounded-lg bg-white hover:bg-slate-100 text-slate-700 hover:text-slate-900 border border-slate-200 shadow-2xs transition-colors"
            >
              {sample.name}
            </button>
          ))}
        </div>

        {/* Advanced Options Toggle */}
        <div className="mt-4">
          <button
            type="button"
            onClick={() => setShowOptions(!showOptions)}
            className="inline-flex items-center gap-1.5 text-xs font-semibold text-slate-600 hover:text-slate-900 transition-colors px-1"
          >
            <SlidersHorizontal className="h-3.5 w-3.5 text-indigo-600" />
            <span>Customize Tone & Details</span>
            {showOptions ? <ChevronUp className="h-3.5 w-3.5" /> : <ChevronDown className="h-3.5 w-3.5" />}
          </button>

          {showOptions && (
            <div className="mt-3 p-4 sm:p-5 rounded-2xl bg-white border border-slate-200 shadow-sm space-y-4 animate-in fade-in duration-200">
              {/* Tone Selection */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-2">
                  Review Tone
                </label>
                <div className="grid grid-cols-2 sm:grid-cols-5 gap-2">
                  {TONES.map((t) => (
                    <button
                      key={t.id}
                      type="button"
                      onClick={() => setTone(t.id)}
                      className={`p-2.5 rounded-xl text-left border transition-all ${
                        tone === t.id
                          ? 'bg-indigo-50 border-indigo-500 text-indigo-900 shadow-xs'
                          : 'bg-slate-50 border-slate-200 text-slate-700 hover:bg-slate-100'
                      }`}
                    >
                      <div className="font-bold text-xs text-slate-900">{t.label}</div>
                      <div className="text-[10px] text-slate-500 mt-0.5 leading-tight">{t.desc}</div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Optional Custom Notes */}
              <div>
                <label className="block text-xs font-bold uppercase tracking-wider text-slate-700 mb-1.5">
                  Specific Memory or Highlight (Optional)
                </label>
                <input
                  type="text"
                  value={customNotes}
                  onChange={(e) => setCustomNotes(e.target.value)}
                  placeholder="e.g. Guide Marco was brilliant; sunset views over the Forum were incredible"
                  className="w-full px-3.5 py-2.5 rounded-xl bg-slate-50 border border-slate-200 text-xs text-slate-900 placeholder-slate-400 focus:bg-white focus:outline-none focus:border-indigo-500 focus:ring-1 focus:ring-indigo-500 transition-colors"
                />
              </div>
            </div>
          )}
        </div>
      </form>
    </div>
  );
}

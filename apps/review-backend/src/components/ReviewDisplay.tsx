'use client';

import React, { useState } from 'react';
import {
  Star,
  Copy,
  Check,
  Edit3,
  RotateCcw,
  Quote,
  ShieldCheck,
} from 'lucide-react';
import confetti from 'canvas-confetti';
import { ReviewResult, ReviewTone } from '@/lib/types';

interface ReviewDisplayProps {
  review: ReviewResult;
  onRegenerateTone: (tone: ReviewTone) => void;
  isLoadingRegen?: boolean;
}

export function ReviewDisplay({
  review,
  onRegenerateTone,
  isLoadingRegen = false,
}: ReviewDisplayProps) {
  const [copied, setCopied] = useState(false);
  const [isEditing, setIsEditing] = useState(false);
  const [editedText, setEditedText] = useState(review.text);
  const [prevReviewText, setPrevReviewText] = useState(review.text);

  if (review.text !== prevReviewText) {
    setPrevReviewText(review.text);
    setEditedText(review.text);
  }

  const handleCopy = () => {
    navigator.clipboard.writeText(editedText);
    setCopied(true);

    // Fire confetti celebration
    try {
      confetti({
        particleCount: 50,
        spread: 60,
        origin: { y: 0.7 },
        colors: ['#6366f1', '#f43f5e', '#f59e0b', '#10b981'],
      });
    } catch {
      // ignore
    }

    setTimeout(() => setCopied(false), 2500);
  };

  const tones: { id: ReviewTone; label: string }[] = [
    { id: 'balanced', label: 'Balanced' },
    { id: 'enthusiastic', label: 'Enthusiastic' },
    { id: 'casual', label: 'Casual' },
    { id: 'detailed', label: 'Detailed' },
    { id: 'punchy', label: 'Punchy' },
  ];

  return (
    <div className="w-full rounded-2xl bg-white border border-slate-200 p-6 sm:p-8 shadow-sm relative overflow-hidden">
      {/* Header bar: Rating & Verified Traveler */}
      <div className="flex flex-wrap items-center justify-between gap-4 pb-5 border-b border-slate-100 relative z-10">
        <div className="flex items-center gap-3">
          {/* Star rating */}
          <div className="flex items-center gap-1">
            {[...Array(5)].map((_, i) => (
              <Star
                key={i}
                className="h-5 w-5 fill-amber-400 text-amber-400"
              />
            ))}
          </div>
          <span className="text-sm font-black text-slate-900">5.0</span>
          <span className="text-xs text-slate-300 hidden sm:inline">•</span>
          <div className="inline-flex items-center gap-1.5 px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200">
            <ShieldCheck className="h-3.5 w-3.5" />
            <span>Verified Booking</span>
          </div>
        </div>

        {/* Author / Metadata */}
        <div className="text-xs text-slate-500 flex items-center gap-2">
          <span>By <strong className="text-slate-800">{review.authorName || 'Traveler'}</strong></span>
          <span>•</span>
          <span className="capitalize px-2 py-0.5 rounded-md bg-slate-100 text-slate-700 font-medium">
            {review.tone} tone
          </span>
        </div>
      </div>

      {/* Review Body */}
      <div className="my-6 relative z-10">
        <Quote className="h-8 w-8 text-indigo-200 mb-2 -ml-1" />

        {review.headline && !isEditing && (
          <h3 className="text-lg sm:text-xl font-extrabold text-slate-900 mb-3 tracking-tight">
            &ldquo;{review.headline}&rdquo;
          </h3>
        )}

        {isEditing ? (
          <div>
            <textarea
              value={editedText}
              onChange={(e) => setEditedText(e.target.value)}
              rows={4}
              className="w-full p-4 rounded-xl bg-slate-50 border border-indigo-400 text-slate-900 text-base leading-relaxed focus:bg-white focus:outline-none focus:ring-2 focus:ring-indigo-100 resize-none font-sans"
            />
            <div className="flex justify-end gap-2 mt-2">
              <button
                onClick={() => {
                  setEditedText(review.text);
                  setIsEditing(false);
                }}
                className="px-3 py-1.5 rounded-lg text-xs font-semibold text-slate-500 hover:text-slate-800"
              >
                Reset
              </button>
              <button
                onClick={() => setIsEditing(false)}
                className="px-3.5 py-1.5 rounded-lg text-xs font-bold bg-indigo-600 text-white hover:bg-indigo-700 shadow-xs"
              >
                Done Editing
              </button>
            </div>
          </div>
        ) : (
          <p className="text-base sm:text-lg text-slate-700 leading-relaxed font-normal">
            {editedText}
          </p>
        )}

        {/* Tags */}
        {review.tags && review.tags.length > 0 && !isEditing && (
          <div className="mt-4 flex flex-wrap gap-2">
            {review.tags.map((tag) => (
              <span
                key={tag}
                className="px-2.5 py-1 rounded-md text-xs font-medium bg-slate-100 text-slate-700 border border-slate-200/60"
              >
                #{tag.replace(/\s+/g, '')}
              </span>
            ))}
          </div>
        )}
      </div>

      {/* Actions Footer */}
      <div className="pt-5 border-t border-slate-100 flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 relative z-10">
        {/* Tone Switchers */}
        <div className="flex items-center gap-1.5 flex-wrap">
          <span className="text-xs text-slate-500 font-semibold mr-1 flex items-center gap-1">
            <RotateCcw className="h-3 w-3 text-slate-400" />
            Tone:
          </span>
          {tones.map((t) => (
            <button
              key={t.id}
              onClick={() => onRegenerateTone(t.id)}
              disabled={isLoadingRegen || review.tone === t.id}
              className={`px-2.5 py-1 rounded-lg text-xs font-semibold transition-all ${
                review.tone === t.id
                  ? 'bg-indigo-600 text-white shadow-xs'
                  : 'bg-slate-100 text-slate-600 hover:text-slate-900 hover:bg-slate-200 disabled:opacity-40'
              }`}
            >
              {t.label}
            </button>
          ))}
        </div>

        {/* Buttons: Edit & Copy */}
        <div className="flex items-center gap-2 self-end sm:self-auto">
          <button
            onClick={() => setIsEditing(!isEditing)}
            className="inline-flex items-center gap-1.5 px-3 py-2 rounded-xl text-xs font-semibold text-slate-700 hover:text-slate-900 bg-slate-100 hover:bg-slate-200 border border-slate-200 transition-colors shadow-2xs"
          >
            <Edit3 className="h-3.5 w-3.5 text-slate-500" />
            <span>{isEditing ? 'Cancel' : 'Edit Text'}</span>
          </button>

          <button
            onClick={handleCopy}
            className={`inline-flex items-center gap-2 px-5 py-2.5 rounded-xl font-bold text-sm transition-all shadow-md ${
              copied
                ? 'bg-emerald-600 text-white shadow-emerald-200'
                : 'bg-gradient-to-r from-indigo-600 via-indigo-500 to-rose-600 hover:from-indigo-700 hover:to-rose-700 text-white shadow-indigo-200'
            }`}
          >
            {copied ? (
              <>
                <Check className="h-4 w-4" />
                <span>Copied to Clipboard!</span>
              </>
            ) : (
              <>
                <Copy className="h-4 w-4 text-indigo-100" />
                <span>Copy Review</span>
              </>
            )}
          </button>
        </div>
      </div>
    </div>
  );
}

'use client';

import React from 'react';
import { X, History, Trash2, Copy, Check } from 'lucide-react';
import { HistoryItem } from '@/lib/types';

interface HistoryDrawerProps {
  isOpen: boolean;
  onClose: () => void;
  items: HistoryItem[];
  onSelect: (item: HistoryItem) => void;
  onClear: () => void;
  onDeleteOne: (id: string) => void;
}

export function HistoryDrawer({
  isOpen,
  onClose,
  items,
  onSelect,
  onClear,
  onDeleteOne,
}: HistoryDrawerProps) {
  const [copiedId, setCopiedId] = React.useState<string | null>(null);

  if (!isOpen) return null;

  const handleCopyReview = (text: string, id: string, e: React.MouseEvent) => {
    e.stopPropagation();
    navigator.clipboard.writeText(text);
    setCopiedId(id);
    setTimeout(() => setCopiedId(null), 2000);
  };

  return (
    <div className="fixed inset-0 z-50 overflow-hidden bg-slate-900/40 backdrop-blur-xs animate-in fade-in duration-200">
      <div className="absolute inset-y-0 right-0 max-w-full flex pl-10">
        <div className="w-screen max-w-md bg-white border-l border-slate-200 shadow-2xl flex flex-col">
          {/* Header */}
          <div className="p-5 border-b border-slate-100 flex items-center justify-between">
            <div className="flex items-center gap-2">
              <History className="h-5 w-5 text-indigo-600" />
              <h2 className="text-lg font-bold text-slate-900">Review History</h2>
              <span className="text-xs px-2 py-0.5 rounded-full bg-slate-100 text-slate-700 font-mono font-bold">
                {items.length}
              </span>
            </div>
            <div className="flex items-center gap-2">
              {items.length > 0 && (
                <button
                  onClick={onClear}
                  className="p-1.5 rounded-lg text-slate-400 hover:text-rose-600 hover:bg-slate-100 transition-colors"
                  title="Clear All History"
                >
                  <Trash2 className="h-4 w-4" />
                </button>
              )}
              <button
                onClick={onClose}
                className="p-1.5 rounded-lg text-slate-400 hover:text-slate-900 hover:bg-slate-100 transition-colors"
              >
                <X className="h-5 w-5" />
              </button>
            </div>
          </div>

          {/* List Content */}
          <div className="flex-1 overflow-y-auto p-4 space-y-4">
            {items.length === 0 ? (
              <div className="text-center py-16 px-4">
                <History className="h-10 w-10 text-slate-400 mx-auto mb-3 opacity-60" />
                <h4 className="text-sm font-bold text-slate-800">No generated reviews yet</h4>
                <p className="text-xs text-slate-500 mt-1 max-w-xs mx-auto">
                  When you generate a review for a GetYourGuide tour, it will automatically be saved
                  here for easy reference.
                </p>
              </div>
            ) : (
              items.map((item) => (
                <div
                  key={item.id}
                  onClick={() => {
                    onSelect(item);
                    onClose();
                  }}
                  className="p-4 rounded-xl bg-slate-50 border border-slate-200 hover:border-indigo-400 hover:bg-white cursor-pointer transition-all duration-200 group shadow-2xs"
                >
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <h4 className="text-sm font-bold text-slate-900 group-hover:text-indigo-600 transition-colors line-clamp-1">
                        {item.tour.title}
                      </h4>
                      <p className="text-xs text-slate-500 mt-0.5">{item.tour.location}</p>
                    </div>

                    <div className="flex items-center gap-1 shrink-0">
                      <button
                        onClick={(e) => handleCopyReview(item.review.text, item.id, e)}
                        className="p-1.5 rounded-lg bg-white hover:bg-slate-100 text-slate-600 hover:text-slate-900 border border-slate-200 transition-colors shadow-2xs"
                        title="Copy Review Text"
                      >
                        {copiedId === item.id ? (
                          <Check className="h-3.5 w-3.5 text-emerald-600" />
                        ) : (
                          <Copy className="h-3.5 w-3.5" />
                        )}
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          onDeleteOne(item.id);
                        }}
                        className="p-1.5 rounded-lg bg-white hover:bg-rose-50 text-slate-400 hover:text-rose-600 border border-slate-200 transition-colors shadow-2xs"
                        title="Delete this item"
                      >
                        <Trash2 className="h-3.5 w-3.5" />
                      </button>
                    </div>
                  </div>

                  {/* Review snippet */}
                  <p className="text-xs text-slate-700 mt-2 line-clamp-2 italic bg-white p-2.5 rounded-lg border border-slate-200">
                    &ldquo;{item.review.text}&rdquo;
                  </p>

                  {/* Photo thumbnails */}
                  {item.photos && item.photos.length > 0 && (
                    <div className="mt-3 flex items-center gap-1.5">
                      {item.photos.slice(0, 3).map((photo, i) => (
                        <div
                          key={i}
                          className="h-10 w-14 rounded-md overflow-hidden bg-slate-100 border border-slate-200"
                        >
                          <img
                            src={photo.thumbUrl || photo.url}
                            alt=""
                            className="h-full w-full object-cover"
                          />
                        </div>
                      ))}
                      <span className="ml-auto text-[10px] text-slate-400 font-mono">
                        {new Date(item.timestamp).toLocaleDateString()}
                      </span>
                    </div>
                  )}
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}

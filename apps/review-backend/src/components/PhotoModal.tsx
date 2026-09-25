'use client';

import React, { useEffect, useState } from 'react';
import { X, ChevronLeft, ChevronRight, Download, ExternalLink } from 'lucide-react';
import { PhotoItem } from '@/lib/types';

interface PhotoModalProps {
  photos: PhotoItem[];
  initialIndex: number;
  onClose: () => void;
}

export function PhotoModal({ photos, initialIndex, onClose }: PhotoModalProps) {
  const [currentIndex, setCurrentIndex] = useState(initialIndex);

  const currentPhoto = photos[currentIndex];

  const handlePrev = React.useCallback(() => {
    setCurrentIndex((prev) => (prev > 0 ? prev - 1 : photos.length - 1));
  }, [photos.length]);

  const handleNext = React.useCallback(() => {
    setCurrentIndex((prev) => (prev < photos.length - 1 ? prev + 1 : 0));
  }, [photos.length]);

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
      if (e.key === 'ArrowLeft') handlePrev();
      if (e.key === 'ArrowRight') handleNext();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [handlePrev, handleNext, onClose]);

  const handleDownload = async () => {
    try {
      const targetUrl = currentPhoto.downloadUrl || currentPhoto.url;
      const res = await fetch(targetUrl);
      const blob = await res.blob();
      const blobUrl = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = blobUrl;
      a.download = `review-photo-${currentPhoto.id}.jpg`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(blobUrl);
    } catch {
      window.open(currentPhoto.downloadUrl || currentPhoto.url, '_blank');
    }
  };

  if (!currentPhoto) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/90 backdrop-blur-md p-4 sm:p-6 animate-in fade-in duration-200">
      {/* Top Bar */}
      <div className="absolute top-4 right-4 z-50 flex items-center gap-3">
        <button
          onClick={handleDownload}
          className="p-2.5 rounded-full bg-slate-900/80 hover:bg-slate-800 text-white border border-white/20 transition-transform hover:scale-105"
          title="Download High Resolution"
        >
          <Download className="h-5 w-5" />
        </button>
        <button
          onClick={onClose}
          className="p-2.5 rounded-full bg-slate-900/80 hover:bg-slate-800 text-white border border-white/20 transition-transform hover:scale-105"
          title="Close Modal (Esc)"
        >
          <X className="h-5 w-5" />
        </button>
      </div>

      {/* Navigation Buttons */}
      {photos.length > 1 && (
        <>
          <button
            onClick={handlePrev}
            className="absolute left-4 z-50 p-3 rounded-full bg-black/50 hover:bg-black/80 text-white border border-white/20 transition-transform hover:scale-110"
            title="Previous Photo"
          >
            <ChevronLeft className="h-6 w-6" />
          </button>
          <button
            onClick={handleNext}
            className="absolute right-4 z-50 p-3 rounded-full bg-black/50 hover:bg-black/80 text-white border border-white/20 transition-transform hover:scale-110"
            title="Next Photo"
          >
            <ChevronRight className="h-6 w-6" />
          </button>
        </>
      )}

      {/* Main Image Container */}
      <div className="max-w-5xl max-h-[85vh] w-full flex flex-col items-center">
        <div className="relative overflow-hidden rounded-xl shadow-2xl max-h-[75vh] flex items-center justify-center">
          <img
            src={currentPhoto.url}
            alt={currentPhoto.alt}
            className="max-h-[75vh] max-w-full object-contain rounded-xl"
          />
        </div>

        {/* Caption & Attribution bar */}
        <div className="mt-4 w-full flex flex-col sm:flex-row items-center justify-between text-xs sm:text-sm text-slate-300 gap-2 px-2">
          <div className="text-center sm:text-left truncate max-w-lg">
            <p className="font-medium text-white truncate">{currentPhoto.alt}</p>
            <p className="text-xs text-slate-400 mt-0.5">
              Source: <span className="font-semibold text-indigo-300">{currentPhoto.source}</span>
              {' • '}
              Photo by{' '}
              {currentPhoto.photographerUrl ? (
                <a
                  href={currentPhoto.photographerUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="text-white hover:underline inline-flex items-center gap-1"
                >
                  {currentPhoto.photographer}
                  <ExternalLink className="h-3 w-3" />
                </a>
              ) : (
                <span className="text-white">{currentPhoto.photographer}</span>
              )}
            </p>
          </div>

          <div className="text-xs text-slate-400 font-mono">
            {currentIndex + 1} of {photos.length}
          </div>
        </div>
      </div>
    </div>
  );
}

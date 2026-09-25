'use client';

import React, { useState } from 'react';
import { Maximize2, Download, ExternalLink, Camera } from 'lucide-react';
import { PhotoItem } from '@/lib/types';
import { PhotoModal } from './PhotoModal';

interface PhotoGalleryProps {
  photos: PhotoItem[];
  tourTitle?: string;
}

export function PhotoGallery({ photos }: PhotoGalleryProps) {
  const [selectedPhotoIndex, setSelectedPhotoIndex] = useState<number | null>(null);

  if (!photos || photos.length === 0) {
    return null;
  }

  const handleDownload = async (photo: PhotoItem, e: React.MouseEvent) => {
    e.stopPropagation();
    try {
      const targetUrl = photo.downloadUrl || photo.url;
      const res = await fetch(targetUrl);
      const blob = await res.blob();
      const blobUrl = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = blobUrl;
      a.download = `review-photo-${photo.id}.jpg`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(blobUrl);
    } catch {
      window.open(photo.downloadUrl || photo.url, '_blank');
    }
  };

  return (
    <div className="w-full">
      <div className="flex items-center justify-between mb-4">
        <div>
          <h3 className="text-lg sm:text-xl font-extrabold text-slate-900 flex items-center gap-2">
            <Camera className="h-5 w-5 text-indigo-600" />
            <span>Matching Experience Photos</span>
          </h3>
          <p className="text-xs text-slate-500 mt-0.5">
            3 curated high-resolution photos matching the tour sights and experience
          </p>
        </div>
        <span className="text-xs text-slate-400 hidden sm:inline-block">
          Click any photo to view in full resolution
        </span>
      </div>

      {/* 3-Column Responsive Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 sm:gap-6">
        {photos.map((photo, index) => (
          <div
            key={photo.id || index}
            onClick={() => setSelectedPhotoIndex(index)}
            className="group relative rounded-2xl overflow-hidden bg-white border border-slate-200 shadow-sm cursor-pointer transition-all duration-300 hover:border-indigo-300 hover:shadow-md hover:-translate-y-0.5"
          >
            {/* Image Container */}
            <div className="relative aspect-[4/3] w-full overflow-hidden bg-slate-100">
              <img
                src={photo.url}
                alt={photo.alt}
                loading="lazy"
                className="w-full h-full object-cover transition-transform duration-500 group-hover:scale-105"
                onError={(e) => {
                  (e.target as HTMLElement).style.display = 'none';
                }}
              />

              {/* Source Badge */}
              <div className="absolute top-3 left-3 z-10">
                <span
                  className={`inline-flex items-center px-2 py-0.5 rounded-md text-[11px] font-bold tracking-wide backdrop-blur-md border ${
                    photo.source === 'Unsplash'
                      ? 'bg-slate-900/80 text-white border-white/20'
                      : photo.source === 'Pexels'
                      ? 'bg-emerald-900/80 text-emerald-200 border-emerald-400/30'
                      : photo.source === 'GetYourGuide'
                      ? 'bg-orange-900/80 text-orange-200 border-orange-400/30'
                      : 'bg-indigo-900/80 text-indigo-200 border-indigo-400/30'
                  }`}
                >
                  {photo.source}
                </span>
              </div>

              {/* Overlay on hover */}
              <div className="absolute inset-0 bg-gradient-to-t from-slate-950/80 via-slate-950/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-300 flex flex-col justify-between p-4 z-20">
                {/* Top action icons */}
                <div className="flex justify-end gap-2">
                  <button
                    onClick={(e) => handleDownload(photo, e)}
                    className="p-2 rounded-lg bg-black/60 hover:bg-black/80 text-white backdrop-blur-md border border-white/15 transition-transform hover:scale-110"
                    title="Download Photo"
                  >
                    <Download className="h-4 w-4" />
                  </button>
                  <button
                    onClick={() => setSelectedPhotoIndex(index)}
                    className="p-2 rounded-lg bg-black/60 hover:bg-black/80 text-white backdrop-blur-md border border-white/15 transition-transform hover:scale-110"
                    title="View Fullscreen"
                  >
                    <Maximize2 className="h-4 w-4" />
                  </button>
                </div>

                {/* Bottom caption */}
                <div>
                  <p className="text-xs font-semibold text-white line-clamp-2">{photo.alt}</p>
                </div>
              </div>
            </div>

            {/* Photo Footer / Attribution */}
            <div className="p-3 bg-slate-50 border-t border-slate-100 flex items-center justify-between text-xs text-slate-500">
              <div className="truncate pr-2">
                <span>Photo by </span>
                {photo.photographerUrl ? (
                  <a
                    href={photo.photographerUrl}
                    target="_blank"
                    rel="noopener noreferrer"
                    onClick={(e) => e.stopPropagation()}
                    className="font-semibold text-slate-700 hover:text-indigo-600 transition-colors inline-flex items-center gap-1"
                  >
                    <span className="truncate max-w-[120px]">{photo.photographer}</span>
                    <ExternalLink className="h-3 w-3 shrink-0" />
                  </a>
                ) : (
                  <span className="font-semibold text-slate-700">{photo.photographer}</span>
                )}
              </div>

              <span className="text-[10px] text-slate-400 font-mono shrink-0">
                Photo {index + 1}/3
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Lightbox Modal */}
      {selectedPhotoIndex !== null && (
        <PhotoModal
          photos={photos}
          initialIndex={selectedPhotoIndex}
          onClose={() => setSelectedPhotoIndex(null)}
        />
      )}
    </div>
  );
}

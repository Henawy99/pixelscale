import { PhotoItem } from './types';

export async function fetchPhotosForQueries(
  queries: string[],
  scrapedImages: string[] = [],
  tourLocation: string = ''
): Promise<PhotoItem[]> {
  const photos: PhotoItem[] = [];
  const seenUrls = new Set<string>();

  const unsplashKey = process.env.UNSPLASH_ACCESS_KEY?.trim();
  const pexelsKey = process.env.PEXELS_API_KEY?.trim();

  // 1. Try Unsplash if key is available
  if (unsplashKey && !unsplashKey.includes('your_')) {
    try {
      for (const query of queries.slice(0, 3)) {
        if (photos.length >= 3) break;
        const res = await fetch(
          `https://api.unsplash.com/search/photos?query=${encodeURIComponent(
            query
          )}&per_page=3&orientation=landscape`,
          {
            headers: {
              Authorization: `Client-ID ${unsplashKey}`,
            },
          }
        );
        if (res.ok) {
          const data = await res.json();
          for (const item of data.results || []) {
            if (!seenUrls.has(item.urls.regular)) {
              seenUrls.add(item.urls.regular);
              photos.push({
                id: `unsplash-${item.id}`,
                url: item.urls.regular,
                thumbUrl: item.urls.small,
                alt: item.alt_description || item.description || query,
                photographer: item.user?.name || 'Unsplash Photographer',
                photographerUrl: item.user?.links?.html || 'https://unsplash.com',
                source: 'Unsplash',
                downloadUrl: item.links?.download || item.urls.full,
                query,
              });
              if (photos.length >= 3) break;
            }
          }
        }
      }
    } catch (e) {
      console.warn('Unsplash fetch error:', e);
    }
  }

  // 2. Try Pexels if key is available and need more photos
  if (photos.length < 3 && pexelsKey && !pexelsKey.includes('your_')) {
    try {
      for (const query of queries.slice(0, 3)) {
        if (photos.length >= 3) break;
        const res = await fetch(
          `https://api.pexels.com/v1/search?query=${encodeURIComponent(query)}&per_page=3&orientation=landscape`,
          {
            headers: {
              Authorization: pexelsKey,
            },
          }
        );
        if (res.ok) {
          const data = await res.json();
          for (const item of data.photos || []) {
            if (!seenUrls.has(item.src.large)) {
              seenUrls.add(item.src.large);
              photos.push({
                id: `pexels-${item.id}`,
                url: item.src.large2x || item.src.large,
                thumbUrl: item.src.medium,
                alt: item.alt || query,
                photographer: item.photographer || 'Pexels Contributor',
                photographerUrl: item.photographer_url || 'https://pexels.com',
                source: 'Pexels',
                downloadUrl: item.src.original,
                query,
              });
              if (photos.length >= 3) break;
            }
          }
        }
      }
    } catch (e) {
      console.warn('Pexels fetch error:', e);
    }
  }

  // 3. Try Wikimedia Commons API (Public domain & CC-BY travel photos, zero API key required)
  if (photos.length < 3) {
    try {
      for (const query of queries) {
        if (photos.length >= 3) break;
        // Clean query for Wikimedia
        const cleanQuery = query.replace(/[^\w\s]/gi, ' ').trim();
        const url = `https://commons.wikimedia.org/w/api.php?action=query&generator=search&gsrsearch=${encodeURIComponent(
          cleanQuery
        )}&gsrnamespace=6&gsrlimit=3&prop=imageinfo&iiprop=url|extmetadata&iiurlwidth=1280&format=json`;

        const res = await fetch(url, {
          headers: { 'User-Agent': 'ReviewApp/1.0 (travel-review-curator)' },
        });

        if (res.ok) {
          const data = await res.json();
          const pages = data.query?.pages || {};
          for (const pageId of Object.keys(pages)) {
            const pageTitle = pages[pageId].title || '';
            if (
              pageTitle.toLowerCase().endsWith('.pdf') ||
              pageTitle.toLowerCase().endsWith('.djvu')
            ) {
              continue;
            }
            const info = pages[pageId].imageinfo?.[0];
            const imgUrl = info?.thumburl || info?.url;
            if (imgUrl && !seenUrls.has(imgUrl) && isGoodImageExtension(imgUrl)) {
              seenUrls.add(imgUrl);
              const artistRaw = info?.extmetadata?.Artist?.value || 'Wikimedia Commons';
              const cleanArtist = artistRaw.replace(/<[^>]*>/g, '').trim() || 'Wikimedia Commons';
              photos.push({
                id: `wiki-${pageId}`,
                url: imgUrl,
                thumbUrl: imgUrl,
                alt: cleanQuery,
                photographer: cleanArtist,
                photographerUrl: info?.descriptionurl || 'https://commons.wikimedia.org',
                source: 'Wikimedia',
                downloadUrl: info?.url || imgUrl,
                query,
              });
              if (photos.length >= 3) break;
            }
          }
        }
      }
    } catch (e) {
      console.warn('Wikimedia fetch error:', e);
    }
  }

  // 4. Use scraped tour images if available
  if (photos.length < 3 && scrapedImages.length > 0) {
    for (const scrapedUrl of scrapedImages) {
      if (!seenUrls.has(scrapedUrl)) {
        seenUrls.add(scrapedUrl);
        photos.push({
          id: `gyg-${photos.length + 1}`,
          url: scrapedUrl,
          thumbUrl: scrapedUrl,
          alt: `Official tour picture from ${tourLocation || 'GetYourGuide'}`,
          photographer: 'GetYourGuide Partner',
          photographerUrl: 'https://getyourguide.com',
          source: 'GetYourGuide',
          downloadUrl: scrapedUrl,
          query: tourLocation,
        });
        if (photos.length >= 3) break;
      }
    }
  }

  // 5. High-quality curated landmark photo fallback if fewer than 3 photos found
  if (photos.length < 3) {
    const curations = getCuratedTravelPhotos(tourLocation);
    for (const item of curations) {
      if (!seenUrls.has(item.url)) {
        seenUrls.add(item.url);
        photos.push(item);
        if (photos.length >= 3) break;
      }
    }
  }

  return photos.slice(0, 3);
}

function isGoodImageExtension(url: string): boolean {
  const lower = url.toLowerCase();
  if (
    lower.includes('.pdf') ||
    lower.includes('.djvu') ||
    lower.includes('page1-') ||
    lower.includes('page2-') ||
    lower.includes('.svg') ||
    lower.includes('.tif') ||
    lower.includes('.ogg') ||
    lower.includes('.webm')
  ) {
    return false;
  }

  return (
    lower.endsWith('.jpg') ||
    lower.endsWith('.jpeg') ||
    lower.endsWith('.png') ||
    lower.endsWith('.webp') ||
    lower.includes('.jpg?') ||
    lower.includes('.jpeg?') ||
    lower.includes('.png?') ||
    lower.includes('.webp?')
  );
}

function getCuratedTravelPhotos(location: string): PhotoItem[] {
  const loc = location.toLowerCase();

  if (loc.includes('rome') || loc.includes('colosseum') || loc.includes('italy')) {
    return [
      {
        id: 'curated-rome-1',
        url: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=1600&q=80',
        thumbUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=600&q=80',
        alt: 'Colosseum Rome illuminated at twilight',
        photographer: 'David Köhler',
        photographerUrl: 'https://unsplash.com/@davidkoehler',
        source: 'Unsplash',
        downloadUrl: 'https://images.unsplash.com/photo-1552832230-c0197dd311b5',
        query: 'Colosseum Rome',
      },
      {
        id: 'curated-rome-2',
        url: 'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?auto=format&fit=crop&w=1600&q=80',
        thumbUrl: 'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b?auto=format&fit=crop&w=600&q=80',
        alt: 'Ancient Roman Forum and ruins',
        photographer: 'Christopher Czermak',
        photographerUrl: 'https://unsplash.com/@chrisczermak',
        source: 'Unsplash',
        downloadUrl: 'https://images.unsplash.com/photo-1515542622106-78bda8ba0e5b',
        query: 'Roman Forum',
      },
      {
        id: 'curated-rome-3',
        url: 'https://images.unsplash.com/photo-1525874684015-58379d421a52?auto=format&fit=crop&w=1600&q=80',
        thumbUrl: 'https://images.unsplash.com/photo-1525874684015-58379d421a52?auto=format&fit=crop&w=600&q=80',
        alt: 'St. Peter Basilica and Tiber river in Rome',
        photographer: 'Mauricio Artieda',
        photographerUrl: 'https://unsplash.com/@artieda',
        source: 'Unsplash',
        downloadUrl: 'https://images.unsplash.com/photo-1525874684015-58379d421a52',
        query: 'Rome viewpoints',
      },
    ];
  }

  if (loc.includes('paris') || loc.includes('france') || loc.includes('eiffel')) {
    return [
      {
        id: 'curated-paris-1',
        url: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=1600&q=80',
        thumbUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?auto=format&fit=crop&w=600&q=80',
        alt: 'Eiffel Tower standing tall in Paris',
        photographer: 'Anthony DELANOIX',
        photographerUrl: 'https://unsplash.com/@anthonydelanoix',
        source: 'Unsplash',
        downloadUrl: 'https://images.unsplash.com/photo-1502602898657-3e91760cbb34',
        query: 'Eiffel Tower Paris',
      },
      {
        id: 'curated-paris-2',
        url: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=1600&q=80',
        thumbUrl: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?auto=format&fit=crop&w=600&q=80',
        alt: 'Seine river cruise Paris bridges',
        photographer: 'Alexander Kagan',
        photographerUrl: 'https://unsplash.com/@alexkagan',
        source: 'Unsplash',
        downloadUrl: 'https://images.unsplash.com/photo-1499856871958-5b9627545d1a',
        query: 'Paris Seine cruise',
      },
      {
        id: 'curated-paris-3',
        url: 'https://images.unsplash.com/photo-1509356843151-3e7d96241e11?auto=format&fit=crop&w=1600&q=80',
        thumbUrl: 'https://images.unsplash.com/photo-1509356843151-3e7d96241e11?auto=format&fit=crop&w=600&q=80',
        alt: 'Louvre museum pyramid courtyard Paris',
        photographer: 'Earth',
        photographerUrl: 'https://unsplash.com/@earth',
        source: 'Unsplash',
        downloadUrl: 'https://images.unsplash.com/photo-1509356843151-3e7d96241e11',
        query: 'Louvre Paris',
      },
    ];
  }

  // Global default travel collection
  return [
    {
      id: 'curated-global-1',
      url: 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=1600&q=80',
      thumbUrl: 'https://images.unsplash.com/photo-1488646953014-85cb44e25828?auto=format&fit=crop&w=600&q=80',
      alt: 'World traveler exploring scenic historic streets',
      photographer: 'Francesca Tirico',
      photographerUrl: 'https://unsplash.com/@francescatirico',
      source: 'Unsplash',
      downloadUrl: 'https://images.unsplash.com/photo-1488646953014-85cb44e25828',
      query: 'Traveler landmark explore',
    },
    {
      id: 'curated-global-2',
      url: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=1600&q=80',
      thumbUrl: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800?auto=format&fit=crop&w=600&q=80',
      alt: 'Iconic journey viewpoint during sunset tour',
      photographer: 'Dino Reichmuth',
      photographerUrl: 'https://unsplash.com/@dinoreichmuth',
      source: 'Unsplash',
      downloadUrl: 'https://images.unsplash.com/photo-1469854523086-cc02fe5d8800',
      query: 'Scenic travel viewpoint',
    },
    {
      id: 'curated-global-3',
      url: 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=1600&q=80',
      thumbUrl: 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1?auto=format&fit=crop&w=600&q=80',
      alt: 'Scenic boat cruise and waterfront sightseeing',
      photographer: 'Luca Bravo',
      photographerUrl: 'https://unsplash.com/@lucabravo',
      source: 'Unsplash',
      downloadUrl: 'https://images.unsplash.com/photo-1476514525535-07fb3b4ae5f1',
      query: 'Guided cruise landmark',
    },
  ];
}

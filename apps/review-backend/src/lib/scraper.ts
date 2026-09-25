import * as cheerio from 'cheerio';

export interface ScrapedTourData {
  title: string;
  location: string;
  city: string;
  country: string;
  description: string;
  highlights: string[];
  inclusions: string[];
  duration: string;
  images: string[];
  rawText: string;
  isDirectScrapeSuccess: boolean;
}

export function isValidGetYourGuideUrl(rawUrl: string): boolean {
  try {
    const url = new URL(rawUrl.trim());
    const host = url.hostname.toLowerCase();
    const isGYGHost =
      host === 'getyourguide.com' ||
      host.endsWith('.getyourguide.com') ||
      host.endsWith('.getyourguide.co.uk') ||
      host.endsWith('.getyourguide.de') ||
      host.endsWith('.getyourguide.fr') ||
      host.endsWith('.getyourguide.it') ||
      host.endsWith('.getyourguide.es');

    if (!isGYGHost) return false;
    // Should have a valid path (not just homepage)
    return url.pathname.length > 3;
  } catch {
    return false;
  }
}

/**
 * Parses GetYourGuide semantic URL structure to extract location and tour title hints.
 * Example: https://www.getyourguide.com/rome-l33/colosseum-underground-and-ancient-rome-tour-t412217/
 */
export function parseGetYourGuideUrlSlug(rawUrl: string): {
  cityHint: string;
  titleHint: string;
  tourId: string;
} {
  try {
    const url = new URL(rawUrl.trim());
    const segments = url.pathname
      .split('/')
      .filter((s) => s.length > 0 && !['activity', 's'].includes(s));

    let cityHint = '';
    let titleHint = '';
    let tourId = '';

    for (const segment of segments) {
      // Check for location slug like "rome-l33" or "paris-l16"
      const locMatch = segment.match(/^([a-z-]+)-l\d+$/i);
      if (locMatch) {
        cityHint = locMatch[1].replace(/-/g, ' ');
      }

      // Check for tour slug like "colosseum-underground-tour-t412217"
      const tourMatch = segment.match(/^([a-z0-9-]+)-t(\d+)\/?$/i);
      if (tourMatch) {
        // Strip the tour ID from the title
        titleHint = tourMatch[1].replace(/-/g, ' ');
        tourId = tourMatch[2];
      } else if (!locMatch && segment.length > 3) {
        // Fallback: use segment as-is if no tour ID pattern
        const plainMatch = segment.match(/^([a-z0-9-]+)$/i);
        if (plainMatch) {
          titleHint = plainMatch[1].replace(/-/g, ' ');
        }
      }
    }

    // Capitalize words nicely
    const capitalize = (str: string) =>
      str
        .split(' ')
        .map((w) => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');

    cityHint = capitalize(cityHint);
    titleHint = capitalize(titleHint);

    return { cityHint, titleHint, tourId };
  } catch {
    return { cityHint: '', titleHint: '', tourId: '' };
  }
}

export async function scrapeGetYourGuideTour(targetUrl: string): Promise<ScrapedTourData> {
  const { cityHint, titleHint } = parseGetYourGuideUrlSlug(targetUrl);

  const fallbackData: ScrapedTourData = {
    title: titleHint || 'GetYourGuide Tour Experience',
    location: cityHint || 'Worldwide',
    city: cityHint || '',
    country: '',
    description: '',
    highlights: [],
    inclusions: [],
    duration: '',
    images: [],
    rawText: '',
    isDirectScrapeSuccess: false,
  };

  try {
    const res = await fetch(targetUrl, {
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Referer': 'https://www.google.com/',
      },
      next: { revalidate: 3600 },
    });

    if (!res.ok) {
      return fallbackData;
    }

    const html = await res.text();
    const $ = cheerio.load(html);

    // 1. Title & Meta
    const ogTitle = $('meta[property="og:title"]').attr('content')?.trim() || '';
    const pageTitle = $('title').text().replace(/\|.*GetYourGuide.*/i, '').trim();
    const finalTitle = ogTitle || pageTitle || titleHint;

    const ogDescription = $('meta[property="og:description"]').attr('content')?.trim() || '';
    const metaDescription = $('meta[name="description"]').attr('content')?.trim() || '';
    const finalDescription = ogDescription || metaDescription;

    // 2. Images
    const images: string[] = [];
    const ogImage = $('meta[property="og:image"]').attr('content');
    if (ogImage && ogImage.startsWith('http')) {
      images.push(ogImage);
    }

    // 3. Extract JSON-LD schema
    let jsonLdLocation = '';
    let jsonLdDuration = '';

    $('script[type="application/ld+json"]').each((_, el) => {
      try {
        const rawJson = $(el).text();
        const data = JSON.parse(rawJson);
        const items = Array.isArray(data) ? data : [data];

        for (const item of items) {
          if (item['@type'] === 'TouristAttraction' || item['@type'] === 'Product' || item['@type'] === 'Tour') {
            if (item.image) {
              const itemImages = Array.isArray(item.image) ? item.image : [item.image];
              itemImages.forEach((img: unknown) => {
                const imgUrl = typeof img === 'string' ? img : (img as { url?: string })?.url;
                if (imgUrl && !images.includes(imgUrl)) images.push(imgUrl);
              });
            }
            if (item.description && !finalDescription) {
              fallbackData.description = item.description;
            }
            if (item.duration && !jsonLdDuration) {
              jsonLdDuration = String(item.duration);
            }
            if (item.location?.name && !jsonLdLocation) {
              jsonLdLocation = String(item.location.name);
            }
          }
        }
      } catch {
        // Continue parsing
      }
    });

    // 4. Extract highlights / inclusions from DOM
    const highlights: string[] = [];
    $('ul li, [data-test-id*="highlight"], [data-test-id*="inclusion"]').each((_, el) => {
      const text = $(el).text().trim();
      if (text.length > 10 && text.length < 200 && !highlights.includes(text)) {
        highlights.push(text);
      }
    });

    const cleanBodyText = $('body')
      .text()
      .replace(/\s+/g, ' ')
      .slice(0, 4000);

    return {
      title: finalTitle || titleHint,
      location: jsonLdLocation || cityHint,
      city: cityHint,
      country: '',
      description: finalDescription,
      highlights: highlights.slice(0, 6),
      inclusions: [],
      duration: jsonLdDuration,
      images: images.slice(0, 5),
      rawText: cleanBodyText,
      isDirectScrapeSuccess: true,
    };
  } catch (error) {
    console.warn('Scraper non-critical fetch warning:', error);
    return fallbackData;
  }
}

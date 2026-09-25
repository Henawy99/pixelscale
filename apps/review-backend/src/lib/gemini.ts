import { GoogleGenAI } from '@google/genai';
import { TourAnalysis, ReviewResult, ReviewTone } from './types';
import { ScrapedTourData } from './scraper';

export interface GeminiAnalysisOutput {
  tour: Omit<TourAnalysis, 'originalUrl' | 'scrapedImages'>;
  review: ReviewResult;
  imageQueries: string[];
}

export function getGeminiApiKey(customKey?: string): string | null {
  if (customKey && customKey.trim().length > 10) {
    return customKey.trim();
  }
  const envKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;
  if (envKey && envKey.trim().length > 10 && !envKey.includes('your_')) {
    return envKey.trim();
  }
  return null;
}

export async function analyzeTourAndGenerateReview(
  scrapedData: ScrapedTourData,
  originalUrl: string,
  tone: ReviewTone = 'balanced',
  customNotes?: string,
  customApiKey?: string
): Promise<GeminiAnalysisOutput> {
  const apiKey = getGeminiApiKey(customApiKey);

  if (!apiKey) {
    // If no API key configured, generate a realistic fallback based on scraped data
    return generateFallbackAnalysis(scrapedData, tone, customNotes);
  }

  const ai = new GoogleGenAI({ apiKey });

  const toneInstructions: Record<ReviewTone, string> = {
    balanced:
      'Warm, authentic, balanced traveler review. Sounds like a real traveler who loved the experience without sounding like marketing copy. 3 to 5 sentences.',
    enthusiastic:
      'High-energy, thrilled traveler who cannot stop raving about the highlights, guide, and atmosphere. Authentic excitement, 3 to 5 sentences.',
    casual:
      'Relaxed, conversational traveler tone, like recommending a great activity to a close friend. 3 to 4 sentences.',
    detailed:
      'Observant traveler providing practical tips and specific observations about pacing, guide knowledge, and memorable moments. 4 to 5 sentences.',
    punchy:
      'Short, engaging, high-impact review highlighting the best parts directly. 3 punchy sentences.',
  };

  const prompt = `
You are an expert travel writer who ghostwrites authentic traveler reviews.
You receive data extracted from a GetYourGuide tour page. Your job: analyze the tour and produce a review that sounds like it was written by a real person who actually went on this tour.

INPUT DATA:
- Tour URL: ${originalUrl}
- Title Hint (from URL, may be rough): ${scrapedData.title}
- Location / City: ${scrapedData.location || scrapedData.city || 'Unknown destination'}
- Page Description: ${scrapedData.description || 'N/A'}
- Extracted Highlights: ${scrapedData.highlights.join('; ') || 'N/A'}
${customNotes ? `- Traveler's Specific Memory: "${customNotes}"` : ''}

INSTRUCTIONS:

1. TOUR INFO — Extract & refine:
   - "title": A clean, human-readable tour name. NEVER include tour IDs, product codes, or URL fragments like "T412217". Turn URL slugs into natural English (e.g. "from-salzburg-multilingual-eagle-s-nest-wwii-tour" → "Eagle's Nest & WWII History Tour from Salzburg").
   - "location": "City, Country" format
   - "city": Just the city
   - "country": Just the country
   - "highlights": 3-5 specific things travelers see or do on this tour
   - "duration": Estimated duration (e.g. "3 Hours", "Half-Day")
   - "experienceType": Category (e.g. "Day Trip", "Walking Tour", "Boat Cruise", "Food Tour")
   - "vibe": 1 evocative phrase (e.g. "Breathtaking alpine scenery with a sobering historical twist")
   - "description": 1-2 sentence summary

2. REVIEW — Write an authentic first-person traveler review:
   CRITICAL RULES FOR REALISM:
   - Write as if YOU actually went on this tour last week. Use natural, conversational language.
   - NEVER mention the tour's full official name in the review text. Real people say "this tour", "the experience", "our excursion", or refer to the main sight (e.g. "our visit to the Eagle's Nest").
   - NEVER include tour IDs, booking codes, product numbers, or anything that looks like a catalog reference.
   - NEVER say "GetYourGuide" or any booking platform name.
   - Reference SPECIFIC sights, moments, or details from the tour (e.g. "the views from the terrace were insane" not "the tour was great").
   - Vary sentence structure. Mix short and long sentences. Include at least one sensory detail (what you saw, heard, felt, tasted).
   - Optionally mention the guide by a plausible first name (e.g. "Marco", "Anna", "Stefan").
   - Sound like a real TripAdvisor or Google review, not a press release.
   - Tone: ${toneInstructions[tone]}
   - Length: 3 to 5 sentences.
   - "headline": Short, catchy (e.g. "The views from the Eagle's Nest blew us away!", "Best morning in Rome")
   - "tags": 3 relevant tags (e.g. ["Stunning Views", "Great Guide", "Worth Every Minute"])
   - "rating": 5

3. IMAGE QUERIES — 3 specific photo search queries:
   - Use the actual landmark/sight names + city, NOT the tour title.
   - E.g. "Eagle's Nest Kehlsteinhaus panoramic view", "Salzburg old town aerial", "Berchtesgaden Alps landscape"

OUTPUT: Return ONLY valid JSON, no markdown fences:
{
  "tour": {
    "title": "string",
    "location": "string",
    "city": "string",
    "country": "string",
    "highlights": ["string"],
    "duration": "string",
    "experienceType": "string",
    "vibe": "string",
    "description": "string"
  },
  "review": {
    "headline": "string",
    "text": "string",
    "rating": 5,
    "tone": "${tone}",
    "tags": ["string"]
  },
  "imageQueries": ["string", "string", "string"]
}
`;

  // gemini-3.8-flash is the current free-tier model (older ones are retired)
  const model = 'gemini-3.8-flash';
  const maxRetries = 3;

  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const response = await ai.models.generateContent({
        model,
        contents: prompt,
        config: {
          responseMimeType: 'application/json',
          temperature: 0.7,
        },
      });

      const responseText = response.text?.trim() || '';
      // Parse JSON (strip any accidental fences if present)
      const cleanJson = responseText
        .replace(/^```json\s*/i, '')
        .replace(/^```\s*/i, '')
        .replace(/\s*```$/i, '')
        .trim();

      const parsed = JSON.parse(cleanJson);

      if (parsed.tour && parsed.review && parsed.imageQueries) {
        return {
          tour: {
            title: parsed.tour.title || scrapedData.title,
            location: parsed.tour.location || scrapedData.location,
            city: parsed.tour.city || scrapedData.city,
            country: parsed.tour.country || '',
            highlights: Array.isArray(parsed.tour.highlights) ? parsed.tour.highlights : [],
            duration: parsed.tour.duration || '2-3 Hours',
            experienceType: parsed.tour.experienceType || 'Guided Tour',
            vibe: parsed.tour.vibe || 'Unforgettable travel experience',
            description: parsed.tour.description || scrapedData.description,
          },
          review: {
            text: parsed.review.text,
            headline: parsed.review.headline || 'Incredible experience!',
            rating: parsed.review.rating || 5,
            tone,
            tags: parsed.review.tags || ['Recommended', 'Verified Traveler'],
            authorName: getRandomTravelerName(),
          },
          imageQueries: Array.isArray(parsed.imageQueries)
            ? parsed.imageQueries.slice(0, 3)
            : [scrapedData.title, scrapedData.location],
        };
      }
    } catch (err: unknown) {
      const errorObj = err as { message?: string };
      const is503 =
        errorObj?.message?.includes('503') ||
        errorObj?.message?.includes('UNAVAILABLE') ||
        errorObj?.message?.includes('high demand');
      if (is503 && attempt < maxRetries - 1) {
        // Exponential backoff: 1s, 2s, 4s
        const delayMs = Math.pow(2, attempt) * 1000;
        console.warn(`Gemini 503 on attempt ${attempt + 1}, retrying in ${delayMs}ms...`);
        await new Promise((resolve) => setTimeout(resolve, delayMs));
        continue;
      }
      console.warn(`Gemini attempt ${attempt + 1}/${maxRetries} failed:`, errorObj?.message?.slice(0, 150));
    }
  }

  // If AI generation attempts failed, return realistic fallback
  return generateFallbackAnalysis(scrapedData, tone, customNotes);
}

function getRandomTravelerName(): string {
  const names = [
    'Sarah M.',
    'David K.',
    'Elena R.',
    'Marcus T.',
    'Sophie L.',
    'Alex P.',
    'Jessica W.',
    'Daniel H.',
    'Camilla B.',
    'Liam O.',
  ];
  return names[Math.floor(Math.random() * names.length)];
}

export function generateFallbackAnalysis(
  scrapedData: ScrapedTourData,
  tone: ReviewTone,
  customNotes?: string
): GeminiAnalysisOutput {
  const rawTitle = scrapedData.title || 'Sightseeing & Landmark Tour';
  const location = scrapedData.location || scrapedData.city || 'Europe';
  const city = scrapedData.city || location;

  // Clean the title: remove tour IDs, "From City" prefix noise, etc.
  const cleanTitle = rawTitle
    .replace(/\s*T\d{4,}\s*/gi, '') // Remove tour IDs like T412217
    .replace(/\s+/g, ' ')
    .trim();

  // Extract the main sight/landmark from the title for natural references
  const mainSight = cleanTitle
    .replace(/^from\s+\w+\s+/i, '') // Remove "From Salzburg" prefix
    .replace(/\s*(tour|experience|excursion|trip|tickets?|skip the line|guided|multilingual|private|small group)\s*/gi, ' ')
    .replace(/\s+/g, ' ')
    .trim() || city;

  const defaultHighlights = [
    `Priority skip-the-line access to the main attraction`,
    `Expert commentary from a passionate local guide`,
    `Hidden details and history you won't find in guidebooks`,
    `Perfect photo opportunities at iconic viewpoints`,
  ];

  const highlights =
    scrapedData.highlights.length > 0 ? scrapedData.highlights.slice(0, 4) : defaultHighlights;

  // Pick a random guide name for realism
  const guideNames = ['Marco', 'Anna', 'Stefan', 'Lucia', 'Thomas', 'Elena', 'Giovanni', 'Sophie'];
  const guideName = guideNames[Math.floor(Math.random() * guideNames.length)];

  let reviewText = '';
  let headline = '';

  switch (tone) {
    case 'enthusiastic':
      reviewText = `Honestly, our visit to ${mainSight} was the highlight of our entire trip to ${city}! ${guideName} was absolutely incredible — so passionate and full of stories that made everything come alive. The views alone were worth it, but learning the history behind every corner made it ten times better. ${customNotes ? customNotes + ' ' : ''}If you're visiting ${city}, do NOT skip this. We're still talking about it weeks later!`;
      headline = `Best thing we did in ${city} — hands down!`;
      break;
    case 'casual':
      reviewText = `So we did this tour to ${mainSight} and honestly it was really solid. ${guideName} was super laid-back but clearly knew everything about the area, pointed out stuff we'd have walked right past on our own. The whole thing was well-organized, no awkward waiting around, and the group size was perfect. Would totally recommend it to anyone heading to ${city}.`;
      headline = `Chill, well-organized, and totally worth it`;
      break;
    case 'detailed':
      reviewText = `We booked a guided visit to ${mainSight} and were impressed with how well-paced it was from start to finish. ${guideName} kept the group engaged with detailed historical context without ever feeling rushed. The skip-the-line access saved us at least 45 minutes compared to the general queue, which was massive by midday. One tip: bring comfortable shoes and a water bottle — there's quite a bit of walking involved. Overall a well-run, informative experience in ${city} that was excellent value.`;
      headline = `Well-paced, informative, and great value`;
      break;
    case 'punchy':
      reviewText = `${mainSight} was absolutely stunning — the kind of place where you just stand there with your jaw open. ${guideName} was brilliant, the skip-the-line access was seamless, and the whole experience was over too quickly because we were having such a good time. Don't think twice, just book it.`;
      headline = `Jaw-dropping. Just go.`;
      break;
    case 'balanced':
    default:
      reviewText = `We visited ${mainSight} during our stay in ${city} and it was genuinely one of the best experiences of the trip. ${guideName} was warm and knowledgeable, sharing fascinating details at every stop that really brought the history to life. Having priority access meant we could take our time without feeling rushed, and the photo opportunities were incredible. ${customNotes ? customNotes + ' ' : ''}Really glad we booked this — it made our time in ${city} so much more meaningful.`;
      headline = `A real highlight of our time in ${city}`;
      break;
  }

  return {
    tour: {
      title: cleanTitle,
      location: location,
      city: city,
      country: '',
      highlights,
      duration: scrapedData.duration || '2.5 Hours',
      experienceType: 'Guided Tour & Sightseeing',
      vibe: 'Engaging, scenic and full of discovery',
      description:
        scrapedData.description ||
        `Discover the most iconic sights of ${city} with an expert local guide and priority access.`,
    },
    review: {
      text: reviewText,
      headline,
      rating: 5,
      tone,
      tags: ['Must-Do', 'Great Guide', 'Memorable'],
      authorName: getRandomTravelerName(),
    },
    imageQueries: [
      `${mainSight} ${city} landmark`.trim(),
      `${city} scenic view travel photography`.trim(),
      `${city} historic architecture sunny day`.trim(),
    ],
  };
}

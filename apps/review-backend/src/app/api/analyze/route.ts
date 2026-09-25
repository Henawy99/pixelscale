import { NextRequest, NextResponse } from 'next/server';
import { isValidGetYourGuideUrl, scrapeGetYourGuideTour } from '@/lib/scraper';
import { analyzeTourAndGenerateReview, getGeminiApiKey } from '@/lib/gemini';
import { fetchPhotosForQueries } from '@/lib/photos';
import { AnalyzeRequest, AnalyzeResponse, ReviewTone } from '@/lib/types';

export async function POST(req: NextRequest) {
  try {
    const body: AnalyzeRequest = await req.json().catch(() => ({ url: '' }));
    const { url, tone = 'balanced', customNotes, apiKey: bodyApiKey } = body;

    // Check custom key in headers or body
    const headerKey = req.headers.get('x-gemini-key') || undefined;
    const finalApiKey = headerKey || bodyApiKey;

    if (!url || typeof url !== 'string' || !url.trim()) {
      return NextResponse.json<AnalyzeResponse>(
        {
          success: false,
          error: 'Please enter a GetYourGuide tour URL to continue.',
        },
        { status: 400 }
      );
    }

    const trimmedUrl = url.trim();

    // Validate GetYourGuide URL format
    if (!isValidGetYourGuideUrl(trimmedUrl)) {
      return NextResponse.json<AnalyzeResponse>(
        {
          success: false,
          error:
            'Invalid link. Please paste a valid GetYourGuide tour URL (e.g. https://www.getyourguide.com/rome-l33/colosseum-underground-tour-t412217/).',
        },
        { status: 400 }
      );
    }

    // 1. Scrape tour page / parse metadata
    const scrapedData = await scrapeGetYourGuideTour(trimmedUrl);

    // 2. Analyze with Gemini & Generate authentic traveler review
    const validTones: ReviewTone[] = ['balanced', 'enthusiastic', 'casual', 'detailed', 'punchy'];
    const chosenTone: ReviewTone = validTones.includes(tone) ? tone : 'balanced';

    const hasRealKey = Boolean(getGeminiApiKey(finalApiKey));

    const geminiOutput = await analyzeTourAndGenerateReview(
      scrapedData,
      trimmedUrl,
      chosenTone,
      customNotes,
      finalApiKey
    );

    // 3. Search and fetch 3 matching high-res photos
    const photos = await fetchPhotosForQueries(
      geminiOutput.imageQueries,
      scrapedData.images,
      geminiOutput.tour.location || scrapedData.location
    );

    const responseData: AnalyzeResponse = {
      success: true,
      tour: {
        ...geminiOutput.tour,
        originalUrl: trimmedUrl,
        scrapedImages: scrapedData.images,
      },
      review: geminiOutput.review,
      photos,
      imageQueries: geminiOutput.imageQueries,
      isDemo: !hasRealKey,
    };

    return NextResponse.json(responseData);
  } catch (error: unknown) {
    const errorMsg = error instanceof Error ? error.message : 'An unexpected error occurred while analyzing the tour.';
    console.error('API Error in /api/analyze:', errorMsg);
    return NextResponse.json<AnalyzeResponse>(
      {
        success: false,
        error: errorMsg,
      },
      { status: 500 }
    );
  }
}

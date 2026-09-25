import { NextRequest, NextResponse } from 'next/server';
import { fetchZohoBookings } from '@/lib/zoho';
import { BookingsResponse } from '@/lib/types';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url);
    const emailHeader = req.headers.get('x-zoho-email');
    const passHeader = req.headers.get('x-zoho-password');
    const hostHeader = req.headers.get('x-zoho-host');

    const config = {
      email: emailHeader || url.searchParams.get('email') || undefined,
      password: passHeader || url.searchParams.get('password') || undefined,
      host: hostHeader || url.searchParams.get('host') || undefined,
      forceRefresh: url.searchParams.get('refresh') === 'true' || req.headers.get('x-refresh') === 'true',
    };

    const result = await fetchZohoBookings(config);

    const response: BookingsResponse = {
      success: true,
      bookings: result.bookings,
      total: result.bookings.length,
      source: result.source,
      lastSyncedAt: new Date().toISOString(),
      error: result.error,
      account: config.email || process.env.ZOHO_EMAIL || undefined,
    };

    return NextResponse.json(response);
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Unknown server error';
    return NextResponse.json(
      {
        success: false,
        bookings: [],
        total: 0,
        source: 'mock',
        lastSyncedAt: new Date().toISOString(),
        error: message,
      },
      { status: 500 }
    );
  }
}

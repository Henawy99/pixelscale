import { NextRequest, NextResponse } from 'next/server';
import { fetchAllBookings } from '@/lib/zoho';
import { BookingsResponse } from '@/lib/types';

export const dynamic = 'force-dynamic';

export async function GET(req: NextRequest) {
  try {
    const url = new URL(req.url);

    // Zoho configuration from headers or query params
    const zohoEmailHeader = req.headers.get('x-zoho-email');
    const zohoPassHeader = req.headers.get('x-zoho-password');
    const zohoHostHeader = req.headers.get('x-zoho-host');
    const zohoPortHeader = req.headers.get('x-zoho-port');

    // Gmail configuration from headers or query params
    const gmailEmailHeader = req.headers.get('x-gmail-email');
    const gmailPassHeader = req.headers.get('x-gmail-password');
    const gmailHostHeader = req.headers.get('x-gmail-host');
    const gmailPortHeader = req.headers.get('x-gmail-port');

    const forceRefresh =
      url.searchParams.get('refresh') === 'true' ||
      req.headers.get('x-refresh') === 'true';

    const zohoConfig = {
      email: zohoEmailHeader || url.searchParams.get('email') || undefined,
      password: zohoPassHeader || url.searchParams.get('password') || undefined,
      host: zohoHostHeader || url.searchParams.get('host') || undefined,
      port: zohoPortHeader ? Number(zohoPortHeader) : undefined,
    };

    const gmailConfig = {
      email: gmailEmailHeader || url.searchParams.get('gmailEmail') || undefined,
      password: gmailPassHeader || url.searchParams.get('gmailPassword') || undefined,
      host: gmailHostHeader || url.searchParams.get('gmailHost') || 'imap.gmail.com',
      port: gmailPortHeader ? Number(gmailPortHeader) : 993,
    };

    const result = await fetchAllBookings({
      zoho: zohoConfig,
      gmail: gmailConfig,
      forceRefresh,
    });

    const activeAccount =
      zohoConfig.email && gmailConfig.email
        ? `${zohoConfig.email} + ${gmailConfig.email}`
        : gmailConfig.email ||
          zohoConfig.email ||
          process.env.GMAIL_EMAIL ||
          process.env.ZOHO_EMAIL ||
          undefined;

    const response: BookingsResponse = {
      success: true,
      bookings: result.bookings,
      total: result.bookings.length,
      source: result.source,
      lastSyncedAt: new Date().toISOString(),
      error: result.error,
      account: activeAccount,
      zohoStatus: result.zohoStatus,
      gmailStatus: result.gmailStatus,
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

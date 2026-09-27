import { NextRequest, NextResponse } from 'next/server';
import { ImapFlow } from 'imapflow';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const provider = body.provider || (body.email?.toLowerCase().includes('@gmail.com') ? 'gmail' : 'zoho');

    let email = body.email;
    let password = body.password;

    if (!email && provider === 'gmail') {
      email = process.env.GMAIL_EMAIL;
      password = body.password || process.env.GMAIL_PASSWORD || process.env.GMAIL_APP_PASSWORD;
    } else if (!email) {
      email = process.env.ZOHO_EMAIL;
      password = body.password || process.env.ZOHO_PASSWORD || process.env.ZOHO_APP_PASSWORD;
    }

    const defaultHost =
      provider === 'gmail' || (email && email.toLowerCase().includes('@gmail.com'))
        ? 'imap.gmail.com'
        : 'imappro.zoho.eu';

    const host = body.host || (provider === 'gmail' ? process.env.GMAIL_IMAP_HOST : process.env.ZOHO_IMAP_HOST) || defaultHost;
    const port = Number(body.port || (provider === 'gmail' ? process.env.GMAIL_IMAP_PORT : process.env.ZOHO_IMAP_PORT) || 993);

    if (!email || !password) {
      const name = provider === 'gmail' ? 'Gmail' : 'Zoho';
      return NextResponse.json(
        { success: false, message: `${name} Email and Password are required.` },
        { status: 400 }
      );
    }

    const client = new ImapFlow({
      host,
      port,
      secure: port === 993,
      auth: {
        user: email,
        pass: password,
      },
      logger: false,
    });

    await client.connect();
    const lock = await client.getMailboxLock('INBOX');
    const status = await client.status('INBOX', { messages: true, unseen: true });
    lock.release();
    await client.logout();

    const providerName = provider === 'gmail' ? 'Gmail (Airbnb)' : 'Zoho Mail (GYG)';

    return NextResponse.json({
      success: true,
      message: `Successfully connected to ${providerName} (${email})! Inbox has ${status.messages} messages (${status.unseen || 0} unread).`,
      details: {
        provider,
        host,
        messages: status.messages,
        unseen: status.unseen,
      },
    });
  } catch (err: unknown) {
    const errorObj = err as { message?: string; responseText?: string; response?: string };
    const errorMsg = errorObj?.responseText || errorObj?.message || String(err);
    let hint = '';

    if (errorMsg.includes('AUTHENTICATIONFAILED') || errorMsg.includes('Invalid credentials')) {
      hint = ' Invalid credentials. For Gmail, you MUST use an App Password (16 letters). Go to myaccount.google.com → Security → 2-Step Verification → App passwords to generate one.';
    } else if (errorMsg.toLowerCase().includes('enable imap') || errorMsg.toLowerCase().includes('yet to enable')) {
      hint = ' IMAP access is disabled. Go to your mail provider settings and enable IMAP access.';
    }

    return NextResponse.json(
      {
        success: false,
        message: `Connection failed: ${errorMsg}.${hint}`,
      },
      { status: 400 }
    );
  }
}

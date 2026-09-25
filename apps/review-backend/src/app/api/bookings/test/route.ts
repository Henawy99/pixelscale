import { NextRequest, NextResponse } from 'next/server';
import { ImapFlow } from 'imapflow';

export const dynamic = 'force-dynamic';

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const email = body.email || process.env.ZOHO_EMAIL;
    const password = body.password || process.env.ZOHO_PASSWORD || process.env.ZOHO_APP_PASSWORD;
    const defaultHost = email && email.toLowerCase().includes('@gmail.com') ? 'imap.gmail.com' : 'imap.zoho.eu';
    const host = body.host || process.env.ZOHO_IMAP_HOST || defaultHost;
    const port = Number(body.port || process.env.ZOHO_IMAP_PORT || 993);

    if (!email || !password) {
      return NextResponse.json(
        { success: false, message: 'Zoho Email and Password are required.' },
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

    return NextResponse.json({
      success: true,
      message: `Successfully connected to Zoho Mail (${email}). Inbox has ${status.messages} messages (${status.unseen || 0} unread).`,
      details: {
        host,
        messages: status.messages,
        unseen: status.unseen,
      },
    });
  } catch (err: unknown) {
    const errorObj = err as { message?: string; responseText?: string; response?: string };
    const errorMsg = errorObj?.responseText || errorObj?.message || String(err);
    let hint = '';

    if (errorMsg.toLowerCase().includes('enable imap') || errorMsg.toLowerCase().includes('yet to enable')) {
      hint = ' IMAP access is currently disabled for this Zoho account. To enable it: Log in to mail.zoho.eu → Settings → Mail Accounts → Click your account → Check "Enable IMAP Access" and Save.';
    } else if (errorMsg.includes('AUTHENTICATIONFAILED') || errorMsg.includes('Invalid credentials')) {
      hint = ' Invalid credentials. If 2FA is active, create an App Password at https://accounts.zoho.eu/#security/user_app_password.';
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

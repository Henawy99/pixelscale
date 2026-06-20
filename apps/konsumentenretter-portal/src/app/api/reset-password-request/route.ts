import { NextResponse } from 'next/server';
import { Resend } from 'resend';
import { createClient } from '@supabase/supabase-js';

const resend = new Resend(process.env.RESEND_API_KEY || 're_placeholder');

export async function POST(request: Request) {
  try {
    const { email, redirectTo } = await request.json();

    if (!email) {
      return NextResponse.json({ error: 'E-Mail-Adresse fehlt' }, { status: 400 });
    }

    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder-project.supabase.co';
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key';
    const supabase = createClient(supabaseUrl, serviceKey);

    // Get partner name if available
    let firstName = 'Partner';
    let lastName = '';
    try {
      const { data: partner } = await supabase
        .from('partners')
        .select('first_name, last_name')
        .eq('email', email.toLowerCase().trim())
        .maybeSingle();

      if (partner) {
        firstName = partner.first_name;
        lastName = partner.last_name;
      }
    } catch (e) {
      console.warn('Could not find partner name for reset email:', e);
    }

    // Generate reset password link using admin API
    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: 'recovery',
      email: email.toLowerCase().trim(),
      options: {
        redirectTo: redirectTo || 'https://konsumentenretter-portal.vercel.app/reset-password'
      }
    });

    if (linkError) {
      console.error('Supabase generateLink error:', linkError.message);
      const msg = linkError.message.toLowerCase();
      let germanError = 'Ein Fehler ist beim Erstellen des Links aufgetreten.';
      if (msg.includes('user not found') || msg.includes('no user')) {
        germanError = 'Es wurde kein Partner mit dieser E-Mail-Adresse gefunden.';
      } else if (msg.includes('rate limit')) {
        germanError = 'Zu viele Anfragen. Bitte warte einen Moment und versuche es erneut.';
      }
      return NextResponse.json({ error: germanError }, { status: 400 });
    }

    const actionLink = linkData.properties.action_link;

    // Design the beautifully branded corporate email template
    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Passwort zurücksetzen</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #F8FAFC; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%;">
        <!-- Hidden Preheader Text -->
        <div style="display: none; max-height: 0px; overflow: hidden;">
          Anforderung zum Zurücksetzen deines Passworts für das Konsumentenretter Partner-Portal.
        </div>
        
        <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #F8FAFC; padding: 40px 10px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
          <tr>
            <td align="center">
              <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px; background-color: #FFFFFF; border: 1px solid #E2E8F0; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 12px rgba(10, 22, 40, 0.03);">
                
                <!-- HEADER BAND -->
                <tr>
                  <td align="center" style="background-color: #0A1628; padding: 32px 40px; border-bottom: 3px solid #D4A843;">
                    <table border="0" cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                      <tr>
                        <td align="center" style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 20px; font-weight: 700; color: #FFFFFF; letter-spacing: 3px; text-transform: uppercase;">
                          KONSUMENTEN<span style="color: #00B4D8;">RETTER</span>
                        </td>
                      </tr>
                      <tr>
                        <td align="center" style="padding-top: 4px;">
                          <table border="0" cellpadding="0" cellspacing="0" style="margin: 0 auto;">
                            <tr>
                              <td style="height: 1px; width: 30px; background-color: #D4A843;"></td>
                              <td style="font-family: Georgia, serif; font-size: 9px; color: #D4A843; letter-spacing: 4px; padding: 0 10px; text-transform: uppercase; line-height: 1;">PARTNERNETZWERK</td>
                              <td style="height: 1px; width: 30px; background-color: #D4A843;"></td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- CONTENT -->
                <tr>
                  <td style="padding: 40px; background-color: #FFFFFF;">
                    <h2 style="font-family: Georgia, 'Times New Roman', serif; font-size: 22px; font-weight: normal; color: #0A1628; margin-top: 0; margin-bottom: 24px; line-height: 1.3;">
                      Hallo ${firstName}${lastName ? ` ${lastName}` : ''},
                    </h2>
                    
                    <p style="font-size: 15px; line-height: 1.6; color: #334155; margin-top: 0; margin-bottom: 16px;">
                      wir haben eine Anfrage zum Zurücksetzen des Passworts für deinen Zugang zum <strong>Konsumentenretter Partner-Portal</strong> erhalten.
                    </p>
                    
                    <p style="font-size: 15px; line-height: 1.6; color: #334155; margin-top: 0; margin-bottom: 24px;">
                      Bitte klicke auf den untenstehenden Button, um ein neues Passwort für dein Konto festzulegen:
                    </p>

                    <!-- BUTTON -->
                    <table border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td align="center" style="padding-top: 8px; padding-bottom: 28px;">
                          <a href="${actionLink}" style="background-color: #0A1628; border: 2.5px solid #D4A843; color: #FFFFFF; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 13px; font-weight: bold; text-decoration: none; padding: 14px 28px; border-radius: 4px; display: inline-block; letter-spacing: 1px; text-transform: uppercase;">
                            Passwort neu festlegen
                          </a>
                        </td>
                      </tr>
                    </table>

                    <p style="font-size: 12px; color: #94A3B8; line-height: 1.5; margin-top: 0; margin-bottom: 0;">
                      Sollte der Button nicht funktionieren, kopiere bitte den folgenden Link direkt in die Adresszeile deines Browsers:<br/>
                      <a href="${actionLink}" style="color: #00B4D8; text-decoration: underline;">${actionLink}</a>
                    </p>

                    <table border="0" cellpadding="0" cellspacing="0" width="100%" style="margin-top: 32px; padding-top: 24px; border-top: 1px solid #E2E8F0;">
                      <tr>
                        <td>
                          <p style="font-size: 14px; line-height: 1.5; color: #475569; margin: 0;">
                            Mit freundlichen Grüßen<br>
                            <strong style="color: #0A1628;">Konsumentenretter Team</strong>
                          </p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>

                <!-- FOOTER -->
                <tr>
                  <td style="background-color: #F8FAFC; padding: 30px 40px; border-top: 1px solid #E2E8F0; text-align: center;">
                    <p style="font-size: 11px; line-height: 1.6; color: #94A3B8; margin: 0 0 12px 0;">
                      Diese E-Mail wurde automatisch von Konsumentenretter versendet. Bitte antworte nicht direkt auf diese Nachricht.
                    </p>
                    <p style="font-size: 11px; line-height: 1.6; color: #94A3B8; margin: 0 0 16px 0;">
                      Bei Fragen oder Anregungen wende dich bitte an <a href="mailto:office@konsumentenretter.at" style="color: #64748B; text-decoration: underline;">office@konsumentenretter.at</a>.
                    </p>
                    <p style="font-size: 10px; color: #CBD5E1; margin: 0; text-transform: uppercase; letter-spacing: 0.5px;">
                      &copy; ${new Date().getFullYear()} KONSUMENTENRETTER. ALLE RECHTE VORBEHALTEN.
                    </p>
                  </td>
                </tr>

              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    `;

    // Send email using Resend
    let emailSent = false;
    let emailError = null;

    try {
      const { error: mailErr } = await resend.emails.send({
        from: 'Konsumentenretter Team <office@konsumentenretter.at>',
        to: [email],
        subject: 'Passwort zurücksetzen',
        html: htmlContent,
      });

      if (mailErr) {
        const isVerificationErr =
          mailErr.message.toLowerCase().includes('not verified') ||
          mailErr.message.toLowerCase().includes('verify') ||
          mailErr.message.toLowerCase().includes('validation');

        if (isVerificationErr) {
          const { error: fallbackErr } = await resend.emails.send({
            from: 'Konsumentenretter Team <onboarding@resend.dev>',
            to: [email],
            subject: 'Passwort zurücksetzen',
            html: htmlContent,
          });

          if (fallbackErr) {
            emailError = fallbackErr.message;
          } else {
            emailSent = true;
          }
        } else {
          emailError = mailErr.message;
        }
      } else {
        emailSent = true;
      }
    } catch (mailErr: any) {
      emailError = mailErr.message;
    }

    return NextResponse.json({ success: true, emailSent, emailError });
  } catch (err: any) {
    console.error('Reset password request API error:', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

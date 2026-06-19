import { NextResponse } from 'next/server';
import { Resend } from 'resend';
import { createClient } from '@supabase/supabase-js';

const resend = new Resend(process.env.RESEND_API_KEY || 're_placeholder');

export async function POST(request: Request) {
  try {
    const {
      email,
      firstName,
      lastName,
      birthDate,
      street,
      postalCode,
      city,
      partnerType,
      companyName,
      companyAddress,
      commissionPercent,
      parentPartnerId,
      inviterEmail,
    } = await request.json();

    if (!email || !firstName || !lastName || !commissionPercent) {
      return NextResponse.json(
        { error: 'Missing required parameters' },
        { status: 400 }
      );
    }

    let inviteId = crypto.randomUUID();

    // 1. Insert into Supabase using elevated service role client to bypass client RLS restriction
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder-project.supabase.co';
    const serviceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || 'placeholder-key';
    const supabase = createClient(supabaseUrl, serviceKey);

    // Look up parent ID by inviterEmail if not directly provided
    let finalParentId = parentPartnerId;
    if (!finalParentId && inviterEmail) {
      try {
        const { data: inviterData } = await supabase
          .from('partners')
          .select('id')
          .eq('email', inviterEmail.toLowerCase().trim())
          .single();
        if (inviterData) {
          finalParentId = inviterData.id;
        }
      } catch (err) {
        console.warn('Could not find inviter ID from email on server:', err);
      }
    }

    const percent = parseFloat(commissionPercent);

    // Check if partner with this email already exists
    const { data: existingPartner, error: fetchError } = await supabase
      .from('partners')
      .select('id, status')
      .eq('email', email.toLowerCase().trim())
      .maybeSingle();

    if (fetchError) {
      console.error('Failed to query existing partner:', fetchError.message);
      return NextResponse.json({ error: fetchError.message }, { status: 500 });
    }

    let isResend = false;

    if (existingPartner) {
      if (existingPartner.status !== 'pending') {
        return NextResponse.json(
          { error: 'Ein Partner mit dieser E-Mail-Adresse ist bereits aktiv oder registriert.' },
          { status: 400 }
        );
      }
      // Re-use the existing ID and flag as resend
      inviteId = existingPartner.id;
      isResend = true;

      // Update the existing pending partner details
      const { error: dbError } = await supabase
        .from('partners')
        .update({
          first_name: firstName,
          last_name: lastName,
          birth_date: birthDate || null,
          street: street || null,
          postal_code: postalCode || null,
          city: city || null,
          partner_type: partnerType,
          company_name: partnerType === 'company' ? companyName : null,
          company_address: partnerType === 'company' ? companyAddress : null,
          commission_percent: percent,
          parent_partner_id: finalParentId || null,
          updated_at: new Date().toISOString(),
        })
        .eq('id', inviteId);

      if (dbError) {
        console.error('Database update failed inside API:', dbError.message);
        return NextResponse.json({ error: dbError.message }, { status: 500 });
      }
    } else {
      // Insert new partner
      const { error: dbError } = await supabase.from('partners').insert({
        id: inviteId,
        first_name: firstName,
        last_name: lastName,
        email: email.toLowerCase().trim(),
        birth_date: birthDate || null,
        street: street || null,
        postal_code: postalCode || null,
        city: city || null,
        partner_type: partnerType,
        company_name: partnerType === 'company' ? companyName : null,
        company_address: partnerType === 'company' ? companyAddress : null,
        commission_percent: percent,
        parent_partner_id: finalParentId || null,
        ref_code: `ref_${firstName.toLowerCase().slice(0, 3)}_${lastName.toLowerCase().slice(0, 3)}_${Math.floor(100 + Math.random() * 900)}`,
        status: 'pending',
      });

      if (dbError) {
        console.error('Database insertion failed inside API:', dbError.message);
        return NextResponse.json({ error: dbError.message }, { status: 500 });
      }
    }

    // 2. Dispatch onboarding invitation email via Resend
    const origin = request.headers.get('origin') || 'https://konsumentenretter-portal.vercel.app';
    const link = `${origin}/register/${inviteId}`;

    let emailSent = false;
    let emailError = null;

    const htmlContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Dein Partnervertrag wartet</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #F8FAFC; -webkit-text-size-adjust: 100%; -ms-text-size-adjust: 100%;">
        <!-- Hidden Preheader Text -->
        <div style="display: none; max-height: 0px; overflow: hidden;">
          Herzlich willkommen im Partnernetzwerk von Konsumentenretter. Dein Partnervertrag wartet auf deine Signatur.
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
                      Hallo ${firstName} ${lastName}${companyName ? ` (${companyName})` : ''},
                    </h2>
                    
                    <p style="font-size: 15px; line-height: 1.6; color: #334155; margin-top: 0; margin-bottom: 16px;">
                      herzlich willkommen im Partnernetzwerk von <strong>Konsumentenretter</strong>! Wir freuen uns sehr auf eine erfolgreiche und partnerschaftliche Zusammenarbeit mit dir.
                    </p>
                    
                    <p style="font-size: 15px; line-height: 1.6; color: #334155; margin-top: 0; margin-bottom: 24px;">
                      Du bist nur noch einen Schritt davon entfernt, deinen Registrierungsprozess abzuschließen und Zugriff auf dein persönliches Partner-Portal zu erhalten.
                    </p>

                    <!-- PARTNER SUMMARY CARD -->
                    <table border="0" cellpadding="0" cellspacing="0" width="100%" style="background-color: #F8FAFC; border-left: 4px solid #D4A843; border-top: 1px solid #E2E8F0; border-right: 1px solid #E2E8F0; border-bottom: 1px solid #E2E8F0; border-radius: 0 6px 6px 0; margin-top: 24px; margin-bottom: 28px;">
                      <tr>
                        <td style="padding: 20px;">
                          <table border="0" cellpadding="0" cellspacing="0" width="100%">
                            <tr>
                              <td style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 11px; color: #64748B; padding-bottom: 4px; text-transform: uppercase; letter-spacing: 0.8px; font-weight: 600;">Rolle / Partner-Typ</td>
                              <td style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 11px; color: #64748B; padding-bottom: 4px; text-transform: uppercase; letter-spacing: 0.8px; font-weight: 600; text-align: right;">Beteiligungsquote</td>
                            </tr>
                            <tr>
                              <td style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 15px; font-weight: 700; color: #0A1628; padding-top: 2px;">
                                ${partnerType === 'company' ? 'Vertriebspartner (Firma)' : 'Selbstständiger Partner'}
                              </td>
                              <td style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 16px; font-weight: 700; color: #0A1628; text-align: right; padding-top: 2px;">
                                ${commissionPercent}%
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>

                    <p style="font-size: 15px; line-height: 1.6; color: #334155; margin-top: 0; margin-bottom: 24px;">
                      Bitte klicke auf den untenstehenden Button, um deine Kooperationsvereinbarung zu prüfen und digital zu unterzeichnen:
                    </p>

                    <!-- BUTTON -->
                    <table border="0" cellpadding="0" cellspacing="0" width="100%">
                      <tr>
                        <td align="center" style="padding-top: 8px; padding-bottom: 28px;">
                          <a href="${link}" style="background-color: #0A1628; border: 2.5px solid #D4A843; color: #FFFFFF; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; font-size: 13px; font-weight: bold; text-decoration: none; padding: 14px 28px; border-radius: 4px; display: inline-block; letter-spacing: 1px; text-transform: uppercase;">
                            Vertrag prüfen & signieren
                          </a>
                        </td>
                      </tr>
                    </table>

                    <p style="font-size: 12px; color: #94A3B8; line-height: 1.5; margin-top: 0; margin-bottom: 0;">
                      Sollte der Button nicht funktionieren, kopiere bitte den folgenden Link direkt in die Adresszeile deines Browsers:<br/>
                      <a href="${link}" style="color: #00B4D8; text-decoration: underline;">${link}</a>
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

    try {
      const { error: mailErr } = await resend.emails.send({
        from: 'Konsumentenretter Team <office@konsumentenretter.at>',
        to: [email],
        subject: 'Dein Partnervertrag wartet',
        html: htmlContent,
      });

      if (mailErr) {
        const isVerificationErr =
          mailErr.message.toLowerCase().includes('not verified') ||
          mailErr.message.toLowerCase().includes('verify') ||
          mailErr.message.toLowerCase().includes('validation');

        if (isVerificationErr) {
          console.warn('Domain not verified, retrying with onboarding@resend.dev...');
          const { error: fallbackErr } = await resend.emails.send({
            from: 'Konsumentenretter Team <onboarding@resend.dev>',
            to: [email],
            subject: 'Dein Partnervertrag wartet',
            html: htmlContent,
          });

          if (fallbackErr) {
            emailError = fallbackErr.message;
            console.warn('Resend fallback mail send error:', fallbackErr);
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
      console.warn('Resend send exception:', mailErr);
    }

    return NextResponse.json({
      success: true,
      inviteId,
      emailSent,
      emailError,
    });
  } catch (err: any) {
    console.error('Invite API route error:', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

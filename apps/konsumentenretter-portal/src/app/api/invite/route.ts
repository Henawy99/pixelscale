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

    // 1. Check if partner with this email already exists
    const { data: existingPartner, error: fetchError } = await supabase
      .from('partners')
      .select('id, status')
      .eq('email', email.toLowerCase().trim())
      .maybeSingle();

    if (fetchError) {
      console.error('Failed to query existing partner:', fetchError.message);
      return NextResponse.json({ error: fetchError.message }, { status: 500 });
    }

    if (existingPartner && existingPartner.status !== 'pending') {
      return NextResponse.json(
        { error: 'Ein Partner mit dieser E-Mail-Adresse ist bereits aktiv oder registriert.' },
        { status: 400 }
      );
    }

    // 2. Check Name and Address or Birth Date combination for individuals
    if (firstName && lastName) {
      const { data: nameMatches, error: nameMatchError } = await supabase
        .from('partners')
        .select('id, first_name, last_name, status, email, street, city, birth_date, partner_type, company_name')
        .ilike('first_name', firstName.trim())
        .ilike('last_name', lastName.trim());

      if (nameMatchError) {
        console.error('Failed to query partner name matches:', nameMatchError.message);
      } else if (nameMatches && nameMatches.length > 0) {
        for (const match of nameMatches) {
          if (match.status !== 'pending') {
            // Check street and city match
            if (street && city && match.street && match.city) {
              const matchStreetClean = match.street.replace(/\s+/g, '').toLowerCase();
              const inputStreetClean = street.replace(/\s+/g, '').toLowerCase();
              const matchCityClean = match.city.replace(/\s+/g, '').toLowerCase();
              const inputCityClean = city.replace(/\s+/g, '').toLowerCase();

              if (matchStreetClean === inputStreetClean && matchCityClean === inputCityClean) {
                return NextResponse.json(
                  { error: `Ein aktiver Partner mit diesem Namen und dieser Adresse existiert bereits (E-Mail: ${match.email}).` },
                  { status: 400 }
                );
              }
            }

            // Check birth date match
            if (birthDate && match.birth_date && match.birth_date === birthDate) {
              return NextResponse.json(
                { error: `Ein aktiver Partner mit diesem Namen und diesem Geburtsdatum existiert bereits (E-Mail: ${match.email}).` },
                { status: 400 }
              );
            }
          }
        }
      }
    }

    // 3. Check Company Name and Address combination for corporate partners
    if (partnerType === 'company' && companyName) {
      const { data: companyMatches, error: companyMatchError } = await supabase
        .from('partners')
        .select('id, status, email, company_name, company_address')
        .ilike('company_name', companyName.trim());

      if (companyMatchError) {
        console.error('Failed to query company matches:', companyMatchError.message);
      } else if (companyMatches && companyMatches.length > 0) {
        for (const match of companyMatches) {
          if (match.status !== 'pending') {
            if (companyAddress && match.company_address) {
              const matchAddrClean = match.company_address.replace(/\s+/g, '').toLowerCase();
              const inputAddrClean = companyAddress.replace(/\s+/g, '').toLowerCase();

              if (matchAddrClean === inputAddrClean) {
                return NextResponse.json(
                  { error: `Ein aktiver Partner mit dieser Firma und Firmenadresse existiert bereits (E-Mail: ${match.email}).` },
                  { status: 400 }
                );
              }
            } else {
              return NextResponse.json(
                { error: `Ein aktiver Partner mit dieser Firma existiert bereits (E-Mail: ${match.email}).` },
                { status: 400 }
              );
            }
          }
        }
      }
    }

    let isResend = false;

    if (existingPartner) {
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
      // Generate a random unique 5-digit partner number
      let partnerNumber = String(Math.floor(10000 + Math.random() * 90000));
      try {
        const { data: dupCode } = await supabase
          .from('partners')
          .select('id')
          .eq('ref_code', partnerNumber)
          .maybeSingle();
        if (dupCode) {
          partnerNumber = String(Math.floor(10000 + Math.random() * 90000));
        }
      } catch (err) {
        console.warn('Failed to verify unique partnerNumber:', err);
      }

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
        ref_code: partnerNumber,
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
      <div style="font-family: sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 8px;">
        <h2 style="color: #0A1628;">Hallo ${firstName} ${lastName}${companyName ? ` (${companyName})` : ''},</h2>
        <p style="font-size: 1rem; line-height: 1.6;">
          herzlich willkommen im Team von <strong>Konsumentenretter</strong>! Wir freuen uns sehr auf die Zusammenarbeit mit dir.
        </p>
        <p style="font-size: 1rem; line-height: 1.6;">
          Du bist nur noch <strong>einen Schritt</strong> davon entfernt, den Registrierungsprozess abzuschließen und Zugriff auf dein Partner-Portal zu erhalten.
        </p>
        <p style="font-size: 1rem; line-height: 1.6;">
          Bitte klicke auf den untenstehenden Link, um deine Kooperationsvereinbarung (mit einer vereinbarten Provision von <strong>${commissionPercent}%</strong>) zu prüfen und digital zu unterzeichnen:
        </p>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${link}" style="background-color: #00B4D8; color: white; padding: 12px 24px; text-decoration: none; font-weight: bold; border-radius: 6px; display: inline-block;">
            Vertrag anzeigen & unterzeichnen
          </a>
        </div>
        <p style="font-size: 0.85rem; color: #666; line-height: 1.6;">
          Falls der Button nicht funktioniert, kopiere bitte diesen Link in deinen Browser:<br/>
          <a href="${link}" style="color: #00B4D8;">${link}</a>
        </p>
        <hr style="border: 0; border-top: 1px solid #eee; margin: 30px 0;" />
        <p style="font-size: 0.85rem; color: #888;">
          Diese E-Mail wurde automatisch von Konsumentenretter versendet.
        </p>
      </div>
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

import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

// Server-side Supabase client (uses service role or anon key)
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
);

const GL_RECHT_FORM_URL = (process.env.GL_RECHT_FORM_URL || 'https://gl-recht.at/kreditvertragsgebuhren-koop/').trim();
const GL_RECHT_FORM_ID = (process.env.GL_RECHT_FORM_ID || '15395').trim();
const GL_RECHT_PARTNER = (process.env.GL_RECHT_PARTNER_NAME || 'Konsumentenretter').trim();

// ────────────────────────────────────────────
// Field ID mapping from GL-Recht WPForms form
// ────────────────────────────────────────────
const GL_FIELDS = {
  fullName: '1',       // Vor- und Nachname
  email: '8',          // E-Mail
  birthDay: '5',       // Geburtsdatum (dropdown: d, m, y)
  street: '6',         // Straße und Hausnummer
  city: '26',          // Ort
  zip: '25',           // PLZ
  phone: '7',          // Telefonnummer
  referrer: '52',      // Vermittelt durch
  banks: '54',         // Bank(en) checkboxes
  bankOther: '55',     // Andere Bank (text)
  confirmation: '33',  // Legal consent checkbox
  newsletter: '41',    // Newsletter checkbox
  date: '3',           // Datum (auto-filled, hidden)
  signature: '2',      // Unterschrift
  ausweis: '34',       // Ausweis file upload
  kreditvertrag: '44', // Kreditvertrag file upload
  partner: '46',       // Hidden partner field
  honeypot: '4',       // Honeypot (must be empty)
} as const;

// Bank value mapping (your form → GL-Recht expected values)
const BANK_MAPPING: Record<string, string> = {
  'Wüstenrot': 'Wüstenrot',
  'BAWAG': 'BAWAG',
  'Bank Austria': 'Bank Austria',
  'Erste / Sparkasse': 'Erste/Sparkasse',
  'Raiffeisen': 'Raiffeisen',
  'Oberbank': 'Oberbank',
  'Santander': 'Santander',
  'Volksbank': 'Volksbank',
  'Andere': 'Andere',
};

/**
 * Convert a base64 data URL to a Blob
 */
function dataURLtoBlob(dataURL: string): Blob {
  const parts = dataURL.split(',');
  const mime = parts[0].match(/:(.*?);/)?.[1] || 'image/png';
  const binary = atob(parts[1]);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return new Blob([bytes], { type: mime });
}

/**
 * Format date as DD.MM.YYYY for GL-Recht
 */
function formatDateDE(date: Date): string {
  const dd = String(date.getDate()).padStart(2, '0');
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const yyyy = date.getFullYear();
  return `${dd}.${mm}.${yyyy}`;
}

/**
 * Step 1: Fetch the GL-Recht page and extract nonce + anti-spam tokens
 */
async function extractFormTokens(): Promise<{
  nonce: string;
  token: string;
  tokenTime: string;
  cookies: string;
} | null> {
  try {
    const url = `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}`;
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'de-AT,de;q=0.9,en;q=0.8',
      },
    });

    if (!response.ok) {
      console.error('Failed to fetch GL-Recht page:', response.status);
      return null;
    }

    const html = await response.text();

    // Extract nonce from hidden field
    const nonceMatch = html.match(/name="wpforms\[nonce\]"\s+value="([^"]+)"/);
    // Also try from inline script
    const nonceScriptMatch = html.match(/"wpforms_settings".*?"nonce":"([^"]+)"/);
    const nonce = nonceMatch?.[1] || nonceScriptMatch?.[1] || '';

    // Extract data-token and data-token-time from the form tag
    const tokenMatch = html.match(/data-token="([^"]+)"/);
    const tokenTimeMatch = html.match(/data-token-time="([^"]+)"/);
    const token = tokenMatch?.[1] || '';
    const tokenTime = tokenTimeMatch?.[1] || '';

    // Extract cookies for session continuity
    const setCookies = response.headers.getSetCookie?.() || [];
    const cookies = setCookies.map(c => c.split(';')[0]).join('; ');

    return { nonce, token, tokenTime, cookies };
  } catch (error) {
    console.error('Error extracting form tokens:', error);
    return null;
  }
}

/**
 * Step 2: Forward form data to GL-Recht WPForms
 */
async function forwardToGLRecht(data: {
  fullName: string;
  email: string;
  birthDay: string;
  birthMonth: string;
  birthYear: string;
  street: string;
  city: string;
  zip: string;
  phone: string;
  banks: string[];
  bankOther?: string;
  confirmation: boolean;
  newsletter: boolean;
  signatureData?: string;
  ausweisFiles?: Blob[];
  ausweisNames?: string[];
  vertragFiles?: Blob[];
  vertragNames?: string[];
  refCode?: string;
}): Promise<{ success: boolean; error?: string }> {
  try {
    // Step 1: Get tokens
    const tokens = await extractFormTokens();
    if (!tokens) {
      return { success: false, error: 'Could not extract form tokens from GL-Recht' };
    }

    // Step 2: Build form data
    const formData = new FormData();

    // System fields
    formData.append('wpforms[id]', GL_RECHT_FORM_ID);
    if (tokens.nonce) {
      formData.append('wpforms[nonce]', tokens.nonce);
    }
    formData.append('wpforms[token]', tokens.token);
    formData.append('wpforms[token_time]', tokens.tokenTime);

    // Honeypot (must be empty)
    formData.append(`wpforms[fields][${GL_FIELDS.honeypot}]`, '');

    // Personal data
    formData.append(`wpforms[fields][${GL_FIELDS.fullName}]`, data.fullName);
    formData.append(`wpforms[fields][${GL_FIELDS.email}]`, data.email);
    formData.append(`wpforms[fields][${GL_FIELDS.birthDay}][date][d]`, data.birthDay);
    formData.append(`wpforms[fields][${GL_FIELDS.birthDay}][date][m]`, data.birthMonth);
    formData.append(`wpforms[fields][${GL_FIELDS.birthDay}][date][y]`, data.birthYear);
    formData.append(`wpforms[fields][${GL_FIELDS.street}]`, data.street);
    formData.append(`wpforms[fields][${GL_FIELDS.city}]`, data.city);
    formData.append(`wpforms[fields][${GL_FIELDS.zip}]`, data.zip);
    formData.append(`wpforms[fields][${GL_FIELDS.phone}]`, data.phone);

    // Referrer
    formData.append(`wpforms[fields][${GL_FIELDS.referrer}]`, data.refCode || '');

    // Banks (checkboxes - multiple values)
    for (const bank of data.banks) {
      const mappedBank = BANK_MAPPING[bank] || bank;
      formData.append(`wpforms[fields][${GL_FIELDS.banks}][]`, mappedBank);
    }

    // Other bank name (if "Andere" selected)
    if (data.bankOther) {
      formData.append(`wpforms[fields][${GL_FIELDS.bankOther}]`, data.bankOther);
    }

    // Legal confirmations
    if (data.confirmation) {
      formData.append(
        `wpforms[fields][${GL_FIELDS.confirmation}][]`,
        'ich die unten stehenden Vollmachten sowie den Vollfinanzierungsantrag samt Anlagen gelesen und verstanden habe.'
      );
    }

    // Newsletter
    if (data.newsletter) {
      formData.append(
        `wpforms[fields][${GL_FIELDS.newsletter}][]`,
        'ich den Newsletter erhalten möchte und mit der Verarbeitung meiner Daten zum Versand einverstanden bin.'
      );
    }

    // Date (auto-filled)
    formData.append(`wpforms[fields][${GL_FIELDS.date}]`, formatDateDE(new Date()));

    // Hidden fields required by WPForms validator
    formData.append('page_title', 'Kreditvertragsgebühren – Koop');
    formData.append('page_url', `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}`);
    formData.append('url_referer', '');
    formData.append('page_id', '15387');
    formData.append('wpforms[post_id]', '15387');
    formData.append('wpforms[submit]', 'wpforms-submit');

    // Field 45 is a hidden empty field in form 15395
    formData.append('wpforms[fields][45]', '');

    // Hidden partner field
    formData.append(`wpforms[fields][${GL_FIELDS.partner}]`, GL_RECHT_PARTNER);

    // Signature (base64 string - WPForms Signature addon saves signatures as text input values)
    if (data.signatureData) {
      formData.append(`wpforms[fields][${GL_FIELDS.signature}]`, data.signatureData);
    }

    // Ausweis files (using classic file upload naming convention and dropzone text field name)
    if (data.ausweisFiles && data.ausweisNames) {
      data.ausweisFiles.forEach((blob, idx) => {
        const fileName = data.ausweisNames?.[idx] || `ausweis_${idx}.png`;
        formData.append(`wpforms[fields][${GL_FIELDS.ausweis}][]`, blob, fileName);
        formData.append(`wpforms_${GL_RECHT_FORM_ID}_${GL_FIELDS.ausweis}[]`, blob, fileName);
        formData.append(`wpforms_${GL_RECHT_FORM_ID}_${GL_FIELDS.ausweis}`, blob, fileName);
      });
    }

    // Kreditvertrag files (using classic file upload naming convention and dropzone text field name)
    if (data.vertragFiles && data.vertragNames) {
      data.vertragFiles.forEach((blob, idx) => {
        const fileName = data.vertragNames?.[idx] || `kreditvertrag_${idx}.pdf`;
        formData.append(`wpforms[fields][${GL_FIELDS.kreditvertrag}][]`, blob, fileName);
        formData.append(`wpforms_${GL_RECHT_FORM_ID}_${GL_FIELDS.kreditvertrag}[]`, blob, fileName);
        formData.append(`wpforms_${GL_RECHT_FORM_ID}_${GL_FIELDS.kreditvertrag}`, blob, fileName);
      });
    }

    // Step 3: POST to GL-Recht
    const actionUrl = `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}&wpforms_form_id=${GL_RECHT_FORM_ID}`;

    const postResponse = await fetch(actionUrl, {
      method: 'POST',
      body: formData,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
        'Referer': `${GL_RECHT_FORM_URL}?wpf${GL_RECHT_FORM_ID}_46=${GL_RECHT_PARTNER}`,
        'Origin': 'https://gl-recht.at',
        ...(tokens.cookies ? { 'Cookie': tokens.cookies } : {}),
      },
      redirect: 'follow',
    });

    const htmlResponse = await postResponse.text();
    console.log(`[GL-Recht] Final URL: ${postResponse.url} (Status: ${postResponse.status})`);
    
    // 1. If we got redirected to a thank-you or success page, it is a success!
    const isRedirectSuccess = postResponse.url && (
      postResponse.url.includes('/danke') || 
      postResponse.url.includes('/vielen-dank') ||
      postResponse.url.includes('/success') ||
      (postResponse.url !== actionUrl && !postResponse.url.includes('wpforms_form_id='))
    );
    
    // 2. If the HTML page has a confirmation container, it is a success!
    const isConfirmationSuccess = htmlResponse.includes('wpforms-confirmation') || 
                                   htmlResponse.includes('wpforms-confirmation-container');

    if (isRedirectSuccess || isConfirmationSuccess) {
      console.log(`[GL-Recht] Form forwarded successfully. Target: ${postResponse.url}`);
      return { success: true };
    }

    // 3. Otherwise, check for actual validation error elements inside the HTML body (not stylesheet classes)
    const hasValidationError = htmlResponse.includes('class="wpforms-error"') || 
                               htmlResponse.includes('wpforms-validation-error') || 
                               htmlResponse.includes('wpforms-error-container') ||
                               htmlResponse.includes('id="wpforms-error-container"');

    if (hasValidationError) {
      // Find the validation error message in the HTML if possible
      const errorMatch = htmlResponse.match(/class="wpforms-error"[^>]*>([^<]+)/);
      const errorMsg = errorMatch?.[1]?.trim() || 'Validation error on GL-Recht form';
      console.error(`[GL-Recht] Form submission validation failed: ${errorMsg}`);
      return { success: false, error: errorMsg };
    }

    // Default fallback
    if (postResponse.ok) {
      console.log(`[GL-Recht] Form forwarded with ambiguous status. HTML length: ${htmlResponse.length}`);
      return { success: true };
    } else {
      console.error(`[GL-Recht] Form forwarding failed. Status: ${postResponse.status}`);
      return { success: false, error: `GL-Recht returned ${postResponse.status}` };
    }
  } catch (error) {
    console.error('[GL-Recht] Form forwarding error:', error);
    return { success: false, error: String(error) };
  }
}

// ────────────────────────────────────────────
// Main POST handler
// ────────────────────────────────────────────
export async function POST(request: Request) {
  try {
    const formData = await request.formData();

    // Extract text fields
    const firstName = formData.get('firstName') as string || '';
    const lastName = formData.get('lastName') as string || '';
    const email = formData.get('email') as string || '';
    const birthdate = formData.get('birthdate') as string || '';
    const street = formData.get('street') as string || '';
    const zip = formData.get('zip') as string || '';
    const city = formData.get('city') as string || '';
    const phone = formData.get('phone') as string || '';
    const campaign = formData.get('campaign') as string || 'bearbeitungsgebuehren';
    const rechtsschutz = formData.get('rechtsschutz') as string || '';
    const signatureData = formData.get('signature') as string || '';
    const confirmation = formData.get('confirmation') === 'true';
    const newsletter = formData.get('newsletter') === 'true';
    const refCode = formData.get('ref') as string || '';

    // Providers (banks/casinos/telcos) come as JSON array
    const providersJson = formData.get('providers') as string || '[]';
    let providers: string[] = [];
    try {
      providers = JSON.parse(providersJson);
    } catch {
      providers = [];
    }

    // File uploads
    const ausweisFiles: File[] = formData.getAll('ausweis') as File[];
    const vertragFiles: File[] = formData.getAll('vertrag') as File[];

    // Validate required fields
    if (!firstName || !lastName || !email || !birthdate) {
      return NextResponse.json(
        { error: 'Pflichtfelder fehlen (Vorname, Nachname, E-Mail, Geburtsdatum)' },
        { status: 400 }
      );
    }

    // Parse birthdate
    const birthParts = birthdate.split('-'); // YYYY-MM-DD from <input type="date">
    const birthYear = birthParts[0] || '';
    const birthMonth = birthParts[1] ? String(parseInt(birthParts[1])) : '';
    const birthDay = birthParts[2] ? String(parseInt(birthParts[2])) : '';

    // ─────────────────────────────────────
    // 1. Save lead to Supabase
    // ─────────────────────────────────────
    let leadId: string | null = null;

    // Determine insurance status from rechtsschutz
    const hasInsurance = rechtsschutz === 'Ja';

    // Map campaign slug to enum
    const campaignMap: Record<string, string> = {
      kredit: 'bearbeitungsgebuehren',
      casino: 'casino',
      telekom: 'servicepauschalen',
    };
    const campaignEnum = campaignMap[campaign] || campaign;

    // Look up partner by ref code
    let refPartnerId: string | null = null;
    if (refCode) {
      const { data: partnerData } = await supabase
        .from('partners')
        .select('id')
        .eq('ref_code', refCode)
        .single();
      if (partnerData) {
        refPartnerId = partnerData.id;
      }
    }

    // Determine initial status based on uploaded documents
    const hasAusweis = ausweisFiles.some(file => file.size > 0);
    const hasVertrag = vertragFiles.some(file => file.size > 0);

    let initialStatus = 'vollstaendig';
    if (hasAusweis && hasVertrag) {
      initialStatus = 'vollstaendig';
    } else if (hasAusweis) {
      initialStatus = 'nur_ausweis';
    } else if (hasVertrag) {
      initialStatus = 'nur_vertrag';
    } else {
      initialStatus = 'nur_unterschrieben';
    }

    try {
      const { data: leadData, error: leadError } = await supabase
        .from('leads')
        .insert({
          campaign: campaignEnum,
          ref_partner_id: refPartnerId,
          first_name: firstName,
          last_name: lastName,
          email,
          phone,
          birth_date: birthdate,
          street,
          city,
          postal_code: zip,
          selections: providers,
          has_insurance: hasInsurance,
          insurance_provider: rechtsschutz === 'Ja' ? null : null, // can be extended later
          confirmations: { consent: confirmation, newsletter },
          signature_data: signatureData,
          status: initialStatus,
        })
        .select('id')
        .single();

      if (leadError) {
        console.error('[Supabase] Lead insert error:', leadError);
      } else {
        leadId = leadData?.id || null;
        console.log(`[Supabase] Lead saved: ${leadId}`);
      }
    } catch (dbError) {
      console.error('[Supabase] Database error:', dbError);
      // Continue — we still want to forward to GL-Recht even if DB fails
    }

    // ─────────────────────────────────────
    // 2. Upload files to Supabase Storage
    // ─────────────────────────────────────
    if (leadId) {
      for (const file of ausweisFiles) {
        if (file.size > 0) {
          const filePath = `leads/${leadId}/ausweis/${file.name}`;
          const { error: uploadError } = await supabase.storage
            .from('lead-documents')
            .upload(filePath, file, { contentType: file.type });

          if (!uploadError) {
            await supabase.from('lead_files').insert({
              lead_id: leadId,
              file_type: 'ausweis',
              file_name: file.name,
              file_path: filePath,
              file_size: file.size,
            });
          } else {
            console.error('[Supabase] Ausweis upload error:', uploadError);
          }
        }
      }

      for (const file of vertragFiles) {
        if (file.size > 0) {
          const filePath = `leads/${leadId}/kreditvertrag/${file.name}`;
          const { error: uploadError } = await supabase.storage
            .from('lead-documents')
            .upload(filePath, file, { contentType: file.type });

          if (!uploadError) {
            await supabase.from('lead_files').insert({
              lead_id: leadId,
              file_type: 'kreditvertrag',
              file_name: file.name,
              file_path: filePath,
              file_size: file.size,
            });
          } else {
            console.error('[Supabase] Vertrag upload error:', uploadError);
          }
        }
      }
    }

    // ─────────────────────────────────────
    // 3. Forward to GL-Recht server-side (Kredit only)
    // ─────────────────────────────────────
    let glRechtResult: { success: boolean; error?: string } = { success: true };

    if (campaign === 'kredit' || campaignEnum === 'bearbeitungsgebuehren') {
      try {
        // Convert File objects to Blobs (File extends Blob, so this is fine)
        const ausweisBlobs: Blob[] = ausweisFiles.filter(f => f.size > 0);
        const ausweisNames: string[] = ausweisFiles.filter(f => f.size > 0).map(f => f.name);
        const vertragBlobs: Blob[] = vertragFiles.filter(f => f.size > 0);
        const vertragNames: string[] = vertragFiles.filter(f => f.size > 0).map(f => f.name);

        glRechtResult = await forwardToGLRecht({
          fullName: `${firstName} ${lastName}`,
          email,
          birthDay,
          birthMonth,
          birthYear,
          street,
          city,
          zip,
          phone,
          banks: providers,
          confirmation,
          newsletter,
          signatureData,
          ausweisFiles: ausweisBlobs,
          ausweisNames,
          vertragFiles: vertragBlobs,
          vertragNames,
          refCode,
        });

        if (!glRechtResult.success) {
          console.error('[submit-claim] GL-Recht forwarding failed:', glRechtResult.error);
        }
      } catch (err) {
        console.error('[submit-claim] GL-Recht forwarding error:', err);
        glRechtResult = { success: false, error: String(err) };
      }
    }

    return NextResponse.json({
      success: true,
      leadId,
      glRechtForwarded: glRechtResult.success,
    });
  } catch (error) {
    console.error('[submit-claim] Unexpected error:', error);
    return NextResponse.json(
      { error: 'Ein unerwarteter Fehler ist aufgetreten. Bitte versuchen Sie es erneut.' },
      { status: 500 }
    );
  }
}

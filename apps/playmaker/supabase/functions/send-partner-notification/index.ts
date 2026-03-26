// =====================================================
// SEND PARTNER NOTIFICATION - Supabase Edge Function
// =====================================================
// Sends FCM push notifications to PARTNER app (field owners)
// Supports: new_booking, booking_cancelled
// =====================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.7.1';

// CORS headers for browser requests
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 405,
      });
    }

    // Parse request body
    const body = await req.json();
    const { type, field_id, title, body: messageBody, data } = body;

    if (!type || !field_id || !title || !messageBody) {
      return new Response(JSON.stringify({ error: 'type, field_id, title, and body are required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    console.log(`📲 Processing partner ${type} notification for field: ${field_id}`);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get FCM tokens for partner devices associated with this field
    const { data: devices, error: devicesError } = await supabase
      .from('partner_devices')
      .select('fcm_token')
      .eq('field_id', field_id);

    if (devicesError) {
      console.error('Error fetching partner devices:', devicesError);
      return new Response(JSON.stringify({ error: 'Failed to fetch partner devices', details: devicesError.message }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    if (!devices || devices.length === 0) {
      console.log('⚠️ No partner devices registered for this field');
      return new Response(JSON.stringify({ 
        success: true,
        message: 'No partner devices to notify'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    console.log(`📱 Found ${devices.length} partner device(s)`);

    // Get Firebase credentials
    const firebaseCredentials = Deno.env.get('FIREBASE_CREDENTIALS');
    if (!firebaseCredentials) {
      console.error('FIREBASE_CREDENTIALS not configured');
      return new Response(JSON.stringify({ error: 'Server configuration error: FIREBASE_CREDENTIALS not set' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    const credentials = JSON.parse(firebaseCredentials);
    const projectId = credentials.project_id;

    // Get OAuth 2.0 access token
    const accessToken = await getAccessToken(credentials);

    // Send notification to each partner device
    const results = [];
    for (const device of devices) {
      try {
        const fcmPayload = {
          message: {
            token: device.fcm_token,
            notification: {
              title: title,
              body: messageBody,
            },
            data: {
              type: type,
              field_id: field_id,
              ...data,
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
            android: {
              priority: 'high',
              notification: {
                sound: 'default',
                channelId: 'partner_notifications',
              },
            },
          },
        };

        console.log(`Sending ${type} notification to partner: ${device.fcm_token.substring(0, 20)}...`);

        const fcmResponse = await fetch(
          `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${accessToken}`,
            },
            body: JSON.stringify(fcmPayload),
          }
        );

        const fcmResult = await fcmResponse.json();

        if (fcmResponse.ok) {
          console.log('✅ Partner notification sent successfully');
          results.push({ success: true, token: device.fcm_token.substring(0, 20) + '...' });
        } else {
          console.error('❌ FCM Error:', fcmResult);
          results.push({ success: false, token: device.fcm_token.substring(0, 20) + '...', error: fcmResult });
        }
      } catch (error) {
        console.error('❌ Error sending to partner device:', error);
        results.push({ success: false, token: device.fcm_token.substring(0, 20) + '...', error: error.message });
      }
    }

    return new Response(JSON.stringify({ 
      success: true,
      message: `Partner ${type} notifications processed`,
      results: results
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Error in send-partner-notification:', error);
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      message: error.message 
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/**
 * Get OAuth 2.0 access token for FCM v1 API
 */
async function getAccessToken(credentials: any): Promise<string> {
  const SCOPES = ['https://www.googleapis.com/auth/firebase.messaging'];
  
  const header = {
    alg: 'RS256',
    typ: 'JWT',
  };

  const now = Math.floor(Date.now() / 1000);
  const payload = {
    iss: credentials.client_email,
    scope: SCOPES.join(' '),
    aud: 'https://oauth2.googleapis.com/token',
    exp: now + 3600,
    iat: now,
  };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  const privateKey = await importPrivateKey(credentials.private_key);
  const signature = await sign(unsignedToken, privateKey);
  const encodedSignature = base64UrlEncode(signature);
  
  const jwt = `${unsignedToken}.${encodedSignature}`;

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const tokenData = await tokenResponse.json();
  
  if (!tokenResponse.ok) {
    throw new Error(`Failed to get access token: ${JSON.stringify(tokenData)}`);
  }

  return tokenData.access_token;
}

async function importPrivateKey(pemKey: string): Promise<CryptoKey> {
  const pemContents = pemKey
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  
  const binaryDer = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));

  return await crypto.subtle.importKey(
    'pkcs8',
    binaryDer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign']
  );
}

async function sign(data: string, key: CryptoKey): Promise<string> {
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(data)
  );
  
  return arrayBufferToString(signature);
}

function base64UrlEncode(str: string): string {
  const base64 = btoa(str);
  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

function arrayBufferToString(buffer: ArrayBuffer): string {
  return String.fromCharCode(...new Uint8Array(buffer));
}

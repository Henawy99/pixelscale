// =====================================================
// SEND USER NOTIFICATION - Supabase Edge Function
// =====================================================
// Sends FCM push notifications to USER app users
// Supports: booking_reminder, friend_request, friend_request_declined,
//           squad_join_request, player_joined_game, booking_rejected, match_cancelled
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
    const { type, user_id, user_ids, title, body: messageBody, data } = body;

    if (!type || !title || !messageBody) {
      return new Response(JSON.stringify({ error: 'type, title, and body are required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    console.log(`📲 Processing ${type} notification`);

    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const supabase = createClient(supabaseUrl, supabaseKey);

    // Get FCM tokens for target users
    let fcmTokens: string[] = [];
    
    if (user_id) {
      // Single user
      const { data: userData, error } = await supabase
        .from('player_profiles')
        .select('fcm_token')
        .eq('id', user_id)
        .maybeSingle();
      
      if (error) {
        console.error('Error fetching user:', error);
      } else if (userData?.fcm_token) {
        fcmTokens.push(userData.fcm_token);
      }
    } else if (user_ids && Array.isArray(user_ids)) {
      // Multiple users
      const { data: usersData, error } = await supabase
        .from('player_profiles')
        .select('fcm_token')
        .in('id', user_ids);
      
      if (error) {
        console.error('Error fetching users:', error);
      } else if (usersData) {
        fcmTokens = usersData
          .map((u: any) => u.fcm_token)
          .filter((token: string | null) => token && token.length > 0);
      }
    }

    if (fcmTokens.length === 0) {
      console.log('⚠️ No FCM tokens found for target users');
      return new Response(JSON.stringify({ 
        success: true,
        message: 'No devices to notify'
      }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    console.log(`📱 Found ${fcmTokens.length} device(s) to notify`);

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

    // Send notification to each device
    const results = [];
    for (const token of fcmTokens) {
      try {
        const fcmPayload = {
          message: {
            token: token,
            notification: {
              title: title,
              body: messageBody,
            },
            data: {
              type: type,
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
                channelId: 'playmaker_notifications',
              },
            },
          },
        };

        console.log(`Sending ${type} notification to: ${token.substring(0, 20)}...`);

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
          console.log('✅ Notification sent successfully');
          results.push({ success: true, token: token.substring(0, 20) + '...' });
        } else {
          console.error('❌ FCM Error:', fcmResult);
          results.push({ success: false, token: token.substring(0, 20) + '...', error: fcmResult });
        }
      } catch (error) {
        console.error('❌ Error sending to device:', error);
        results.push({ success: false, token: token.substring(0, 20) + '...', error: error.message });
      }
    }

    return new Response(JSON.stringify({ 
      success: true,
      message: `${type} notifications processed`,
      results: results
    }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Error in send-user-notification:', error);
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

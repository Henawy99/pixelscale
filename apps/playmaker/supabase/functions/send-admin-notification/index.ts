// =====================================================
// SEND ADMIN NOTIFICATION - Supabase Edge Function
// =====================================================
// Sends FCM push notification to admin devices using FCM v1 API
// =====================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';

serve(async (req) => {
  try {
    // Only allow POST requests
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 405,
      });
    }

    // Parse request body
    const { fcm_token, user_name, user_email, user_id, title, body, type } = await req.json();

    if (!fcm_token) {
      return new Response(JSON.stringify({ error: 'FCM token is required' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    // Get Firebase credentials from environment
    const firebaseCredentials = Deno.env.get('FIREBASE_CREDENTIALS');
    if (!firebaseCredentials) {
      console.error('FIREBASE_CREDENTIALS not configured');
      return new Response(JSON.stringify({ error: 'Server configuration error' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    const credentials = JSON.parse(firebaseCredentials);
    const projectId = credentials.project_id;

    // Get OAuth 2.0 access token
    const accessToken = await getAccessToken(credentials);

    // Prepare FCM v1 notification payload
    const notificationTitle = title || '🎉 New User Signed Up!';
    const notificationBody = body || `${user_name || 'New user'} (${user_email || 'No email'}) just created an account`;
    const notificationType = type || 'new_user';

    const fcmPayload = {
      message: {
        token: fcm_token,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          type: notificationType,
          user_id: user_id || '',
          user_name: user_name || '',
          user_email: user_email || '',
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
          },
        },
      },
    };

    console.log('Sending FCM v1 notification:', JSON.stringify(fcmPayload, null, 2));

    // Send notification via FCM v1 API
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
    console.log('FCM Response:', JSON.stringify(fcmResult, null, 2));

    if (!fcmResponse.ok) {
      console.error('FCM Error:', fcmResult);
      return new Response(JSON.stringify({ 
        error: 'Failed to send notification',
        details: fcmResult 
      }), {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    return new Response(JSON.stringify({ 
      success: true,
      message: 'Notification sent successfully',
      fcm_result: fcmResult
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('Error in send-admin-notification:', error);
    return new Response(JSON.stringify({ 
      error: 'Internal server error',
      message: error.message 
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    });
  }
});

/**
 * Get OAuth 2.0 access token for FCM v1 API
 */
async function getAccessToken(credentials: any): Promise<string> {
  const SCOPES = ['https://www.googleapis.com/auth/firebase.messaging'];
  
  // Create JWT
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

  // Encode header and payload
  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const unsignedToken = `${encodedHeader}.${encodedPayload}`;

  // Sign with private key
  const privateKey = await importPrivateKey(credentials.private_key);
  const signature = await sign(unsignedToken, privateKey);
  const encodedSignature = base64UrlEncode(signature);
  
  const jwt = `${unsignedToken}.${encodedSignature}`;

  // Exchange JWT for access token
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

/**
 * Import RSA private key for signing
 */
async function importPrivateKey(pemKey: string): Promise<CryptoKey> {
  // Remove PEM header/footer and decode
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

/**
 * Sign data with private key
 */
async function sign(data: string, key: CryptoKey): Promise<string> {
  const encoder = new TextEncoder();
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    encoder.encode(data)
  );
  
  return arrayBufferToString(signature);
}

/**
 * Base64 URL encode
 */
function base64UrlEncode(str: string): string {
  const base64 = btoa(str);
  return base64
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=/g, '');
}

/**
 * Convert ArrayBuffer to string
 */
function arrayBufferToString(buffer: ArrayBuffer): string {
  return String.fromCharCode(...new Uint8Array(buffer));
}

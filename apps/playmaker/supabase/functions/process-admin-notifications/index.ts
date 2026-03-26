// =====================================================
// PROCESS ADMIN NOTIFICATIONS - Supabase Edge Function
// =====================================================
// Processes the notification queue and sends FCM notifications to admin
// Can be called via:
// 1. HTTP request (manual trigger)
// 2. Cron job (scheduled processing)
// =====================================================

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.42.0';

serve(async (req) => {
  try {
    console.log('🔔 Processing admin notifications...');

    // Create Supabase client with service role
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    );

    // Get Firebase credentials
    const firebaseCredentials = Deno.env.get('FIREBASE_CREDENTIALS');
    if (!firebaseCredentials) {
      console.error('❌ FIREBASE_CREDENTIALS not configured');
      return new Response(JSON.stringify({ error: 'Server configuration error' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    const credentials = JSON.parse(firebaseCredentials);
    const projectId = credentials.project_id;

    // Get OAuth 2.0 access token
    const accessToken = await getAccessToken(credentials);

    // Get all admin devices (for youssef@gmail.com)
    const { data: adminDevices, error: devicesError } = await supabaseClient
      .from('admin_devices')
      .select('fcm_token')
      .eq('admin_email', 'youssef@gmail.com');

    if (devicesError) {
      console.error('❌ Error fetching admin devices:', devicesError);
      return new Response(JSON.stringify({ error: 'Failed to fetch admin devices' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    if (!adminDevices || adminDevices.length === 0) {
      console.log('⚠️ No admin devices registered');
      return new Response(JSON.stringify({ 
        message: 'No admin devices registered',
        processed: 0 
      }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    console.log(`📱 Found ${adminDevices.length} admin device(s)`);

    // Get unprocessed notifications from queue
    const { data: notifications, error: queueError } = await supabaseClient
      .from('admin_notification_queue')
      .select('*')
      .eq('processed', false)
      .order('created_at', { ascending: true })
      .limit(50); // Process max 50 at a time

    if (queueError) {
      console.error('❌ Error fetching notification queue:', queueError);
      return new Response(JSON.stringify({ error: 'Failed to fetch notification queue' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    if (!notifications || notifications.length === 0) {
      console.log('✅ No pending notifications');
      return new Response(JSON.stringify({ 
        message: 'No pending notifications',
        processed: 0 
      }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      });
    }

    console.log(`📬 Processing ${notifications.length} notification(s)...`);

    let successCount = 0;
    let failCount = 0;

    // Send notification for each queued item
    for (const notification of notifications) {
      const notifType = notification.notification_type || 'new_user';
      console.log(`\n📤 Sending notification [${notifType}]: ${notification.title || 'No title'}`);

      // Build notification title and body from new flexible columns
      const notificationTitle = notification.title || '🎉 New User Signed Up!';
      const notificationBody = notification.body || 
        `${notification.user_name || 'New user'} (${notification.user_email}) just created an account`;

      // Merge notification data with user fields for backwards compatibility
      const notificationData = {
        type: notifType,
        ...(notification.data || {}),
        // Include user fields if they exist (for backwards compatibility)
        ...(notification.user_id && { user_id: notification.user_id }),
        ...(notification.user_name && { user_name: notification.user_name }),
        ...(notification.user_email && { user_email: notification.user_email }),
      };

      // ⚠️ FCM requires ALL data values to be strings!
      // Convert all values to strings (booleans, numbers, objects, etc.)
      const stringifiedData: Record<string, string> = {};
      for (const [key, value] of Object.entries(notificationData)) {
        if (value !== null && value !== undefined) {
          stringifiedData[key] = typeof value === 'string' ? value : JSON.stringify(value);
        }
      }

      // Send to all admin devices
      for (const device of adminDevices) {
        const fcmPayload = {
          message: {
            token: device.fcm_token,
            notification: {
              title: notificationTitle,
              body: notificationBody,
            },
            data: stringifiedData, // Use stringified data instead
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

        try {
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
            console.log(`   ✅ Sent to device: ${device.fcm_token.substring(0, 20)}...`);
            console.log(`   📊 FCM Response:`, JSON.stringify(fcmResult));
          } else {
            console.error(`   ❌ Failed to send to device:`, fcmResult);
            console.error(`   📊 FCM Status: ${fcmResponse.status}`);
          }
        } catch (sendError) {
          console.error(`   ❌ Error sending notification:`, sendError);
        }
      }

      // Mark notification as processed
      const { error: updateError } = await supabaseClient
        .from('admin_notification_queue')
        .update({ processed: true })
        .eq('id', notification.id);

      if (updateError) {
        console.error(`❌ Error marking notification as processed:`, updateError);
        failCount++;
      } else {
        successCount++;
      }
    }

    console.log(`\n✅ Processed ${successCount} notification(s), ${failCount} failed`);

    return new Response(JSON.stringify({
      success: true,
      message: `Processed ${successCount} notifications`,
      total: notifications.length,
      success: successCount,
      failed: failCount,
    }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    });

  } catch (error) {
    console.error('❌ Error in process-admin-notifications:', error);
    return new Response(JSON.stringify({
      error: 'Internal server error',
      message: error.message,
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


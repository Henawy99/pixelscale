// Shared FCM Push Notification helper
// Uses Firebase Cloud Messaging HTTP v1 API

interface FCMNotification {
  title: string;
  body: string;
  data?: Record<string, string>;
}

// Get OAuth2 access token from service account
async function getAccessToken(): Promise<string | null> {
  try {
    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!serviceAccountJson) {
      console.error('[FCM] Missing FIREBASE_SERVICE_ACCOUNT_JSON environment variable');
      return null;
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    
    // Create JWT for Google OAuth2
    const header = {
      alg: 'RS256',
      typ: 'JWT',
    };

    const now = Math.floor(Date.now() / 1000);
    const payload = {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      exp: now + 3600,
      iat: now,
    };

    // Encode header and payload
    const encodedHeader = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
    const encodedPayload = btoa(JSON.stringify(payload)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
    
    const unsignedToken = `${encodedHeader}.${encodedPayload}`;

    // Import private key and sign
    const privateKey = serviceAccount.private_key;
    const keyData = privateKey
      .replace('-----BEGIN PRIVATE KEY-----', '')
      .replace('-----END PRIVATE KEY-----', '')
      .replace(/\s/g, '');
    
    const binaryKey = Uint8Array.from(atob(keyData), c => c.charCodeAt(0));
    
    const cryptoKey = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign']
    );

    const signature = await crypto.subtle.sign(
      'RSASSA-PKCS1-v1_5',
      cryptoKey,
      new TextEncoder().encode(unsignedToken)
    );

    const encodedSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_');

    const jwt = `${unsignedToken}.${encodedSignature}`;

    // Exchange JWT for access token
    const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: jwt,
      }),
    });

    if (!tokenResponse.ok) {
      const error = await tokenResponse.text();
      console.error('[FCM] Failed to get access token:', error);
      return null;
    }

    const tokenData = await tokenResponse.json();
    return tokenData.access_token;
  } catch (error) {
    console.error('[FCM] Error getting access token:', error);
    return null;
  }
}

export async function sendPushNotification(
  supabase: any,
  notification: FCMNotification
): Promise<{ success: number; failed: number }> {
  try {
    // Fetch all active device tokens
    const { data: tokens, error } = await supabase
      .from('device_tokens')
      .select('token')
      .gte('updated_at', new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString());

    if (error) {
      console.error('[FCM] Error fetching device tokens:', error);
      return { success: 0, failed: 0 };
    }

    if (!tokens || tokens.length === 0) {
      console.log('[FCM] No device tokens found');
      return { success: 0, failed: 0 };
    }

    const accessToken = await getAccessToken();
    if (!accessToken) {
      console.error('[FCM] Failed to get access token');
      return { success: 0, failed: 0 };
    }

    const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    const serviceAccount = JSON.parse(serviceAccountJson!);
    const projectId = serviceAccount.project_id;

    console.log(`[FCM] Sending notification to ${tokens.length} devices`);

    let successCount = 0;
    let failedCount = 0;

    // Send notifications in parallel using V1 API
    const results = await Promise.allSettled(
      tokens.map(async ({ token }) => {
        try {
          const response = await fetch(
            `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
            {
              method: 'POST',
              headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${accessToken}`,
              },
              body: JSON.stringify({
                message: {
                  token: token,
                  notification: {
                    title: notification.title,
                    body: notification.body,
                  },
                  data: notification.data || {},
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
              }),
            }
          );

          if (!response.ok) {
            const errorText = await response.text();
            console.error(`[FCM] Failed to send to token ${token.substring(0, 10)}...: ${errorText}`);
            
            // Remove invalid tokens
            if (errorText.includes('UNREGISTERED') || errorText.includes('INVALID_ARGUMENT')) {
              console.log(`[FCM] Removing invalid token: ${token.substring(0, 10)}...`);
              await supabase.from('device_tokens').delete().eq('token', token);
            }
            
            throw new Error(errorText);
          }

          return await response.json();
        } catch (error) {
          console.error(`[FCM] Error sending to token ${token.substring(0, 10)}...:`, error);
          throw error;
        }
      })
    );

    // Count successes and failures
    results.forEach((result) => {
      if (result.status === 'fulfilled') {
        successCount++;
      } else {
        failedCount++;
      }
    });

    console.log(`[FCM] Notification sent. Success: ${successCount}, Failed: ${failedCount}`);
    return { success: successCount, failed: failedCount };
  } catch (error) {
    console.error('[FCM] Unexpected error:', error);
    return { success: 0, failed: 0 };
  }
}


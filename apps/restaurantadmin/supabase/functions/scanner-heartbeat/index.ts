/// <reference types="https://esm.sh/@supabase/functions-js@2.0.0/src/edge-runtime.d.ts" />
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { sendPushNotification } from '../_shared/fcm.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-scanner-secret',
};

function json(data: any, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  let payload: any;
  try {
    payload = await req.json();
  } catch (_) {
    return json({ error: 'Invalid JSON payload' }, 400);
  }

  // Validate scanner secret
  const scannerSecretHeader = req.headers.get('x-scanner-secret') ?? req.headers.get('X-Scanner-Secret');
  const configuredScannerSecret = Deno.env.get('SCANNER_SECRET') || '';

  if (!scannerSecretHeader || scannerSecretHeader !== configuredScannerSecret) {
    return json({ error: 'Invalid or missing scanner secret' }, 401);
  }

  // Create service client (bypass RLS)
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
  );

  try {
    const {
      scanner_id,
      scanner_name,
      hostname,
      watch_path,
      action = 'heartbeat', // 'heartbeat', 'startup', 'shutdown'
    } = payload;

    if (!scanner_id) {
      return json({ error: 'scanner_id is required' }, 400);
    }

    // Get current scanner status before update
    const { data: existingScanner } = await supabase
      .from('scanner_heartbeats')
      .select('id, status, scanner_name')
      .eq('scanner_id', scanner_id)
      .maybeSingle();

    const previousStatus = existingScanner?.status || 'offline';
    const newStatus = action === 'shutdown' ? 'offline' : 'online';

    // Upsert heartbeat
    const { data: scanner, error: upsertError } = await supabase
      .from('scanner_heartbeats')
      .upsert({
        scanner_id,
        scanner_name: scanner_name || `Scanner ${scanner_id.substring(0, 8)}`,
        hostname: hostname || 'unknown',
        watch_path: watch_path || '',
        last_heartbeat: new Date().toISOString(),
        status: newStatus,
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'scanner_id',
      })
      .select()
      .single();

    if (upsertError) {
      console.error('[scanner-heartbeat] Upsert error:', upsertError);
      return json({ error: 'Failed to update heartbeat', details: upsertError.message }, 500);
    }

    // Check if status changed - send push notification
    const statusChanged = previousStatus !== newStatus;
    const displayName = scanner_name || `Scanner ${scanner_id.substring(0, 8)}`;

    if (statusChanged) {
      console.log(`[scanner-heartbeat] Status changed: ${previousStatus} -> ${newStatus} for ${displayName}`);

      // Send push notification for status change
      try {
        if (newStatus === 'online') {
          await sendPushNotification(supabase, {
            title: '🟢 Scanner Online',
            body: `${displayName} is now connected and ready to scan receipts.`,
            data: {
              type: 'scanner_status',
              scanner_id,
              status: 'online',
            },
          });
        } else {
          await sendPushNotification(supabase, {
            title: '🔴 Scanner Offline',
            body: `${displayName} has disconnected. Check the scanner PC.`,
            data: {
              type: 'scanner_status',
              scanner_id,
              status: 'offline',
            },
          });
        }
        console.log(`[scanner-heartbeat] Push notification sent for status change`);
      } catch (notificationError) {
        console.error('[scanner-heartbeat] Failed to send push notification:', notificationError);
        // Don't fail the request if push notification fails
      }
    }

    // --- STALENESS CHECK ---
    // Mark any scanner offline if its last heartbeat was more than 90 seconds ago.
    // This handles sudden power loss or script crash (no shutdown heartbeat sent).
    try {
      const stalenessThreshold = new Date(Date.now() - 90 * 1000).toISOString();

      const { data: staleScanner } = await supabase
        .from('scanner_heartbeats')
        .select('scanner_id, scanner_name, status')
        .neq('scanner_id', scanner_id) // Don't check the current one (just updated)
        .eq('status', 'online')        // Only check ones still marked online
        .lt('last_heartbeat', stalenessThreshold);

      if (staleScanner && staleScanner.length > 0) {
        for (const stale of staleScanner) {
          console.log(`[scanner-heartbeat] Stale scanner detected: ${stale.scanner_id} — marking offline`);

          // Mark it offline
          await supabase
            .from('scanner_heartbeats')
            .update({ status: 'offline', updated_at: new Date().toISOString() })
            .eq('scanner_id', stale.scanner_id);

          // Send offline notification
          try {
            const staleName = stale.scanner_name || stale.scanner_id;
            await sendPushNotification(supabase, {
              title: '🔴 Scanner Went Offline',
              body: `${staleName} stopped sending heartbeats. Check the scanner PC.`,
              data: {
                type: 'scanner_status',
                scanner_id: stale.scanner_id,
                status: 'offline',
                reason: 'stale',
              },
            });
          } catch (_) {
            // Don't fail if notification fails
          }
        }
      }
    } catch (stalenessError) {
      // Staleness check is best-effort, don't fail the main request
      console.warn('[scanner-heartbeat] Staleness check failed:', stalenessError);
    }

    return json({
      ok: true,
      scanner_id,
      status: newStatus,
      status_changed: statusChanged,
      previous_status: previousStatus,
      last_heartbeat: scanner?.last_heartbeat,
    });

  } catch (error) {
    console.error('[scanner-heartbeat] Error:', error);
    return json({ error: 'Internal server error', details: String(error) }, 500);
  }
});

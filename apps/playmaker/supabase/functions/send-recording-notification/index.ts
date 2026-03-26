// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface RecordingNotificationRequest {
  booking_id: string;
  title: string;
  body: string;
  event_type: string; // 'recording_started', 'recording_complete', 'recording_failed', 'processing_complete'
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { booking_id, title, body, event_type }: RecordingNotificationRequest = await req.json();

    console.log(`📹 Recording notification: ${event_type} for booking ${booking_id}`);

    // Get booking details to find the host and participants
    const { data: booking, error: bookingError } = await supabaseClient
      .from("bookings")
      .select("host, invitePlayers, footballFieldName")
      .eq("id", booking_id)
      .single();

    if (bookingError || !booking) {
      console.error("Booking not found:", bookingError);
      return new Response(
        JSON.stringify({ error: "Booking not found" }),
        { status: 404, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Collect all user IDs to notify (host + participants)
    const userIds: string[] = [booking.host];
    
    // Add participants (filter out guest IDs)
    if (booking.invitePlayers && Array.isArray(booking.invitePlayers)) {
      for (const playerId of booking.invitePlayers) {
        if (!playerId.startsWith('guest') && !userIds.includes(playerId)) {
          userIds.push(playerId);
        }
      }
    }

    console.log(`📱 Notifying ${userIds.length} users`);

    // Get FCM tokens for all users
    const { data: devices, error: devicesError } = await supabaseClient
      .from("user_devices")
      .select("fcm_token, user_id")
      .in("user_id", userIds);

    if (devicesError) {
      console.error("Error fetching devices:", devicesError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch devices" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!devices || devices.length === 0) {
      console.log("No devices found for users");
      return new Response(
        JSON.stringify({ success: true, message: "No devices to notify" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Send notifications via Firebase
    const fcmTokens = devices.map(d => d.fcm_token).filter(Boolean);
    console.log(`🔔 Sending to ${fcmTokens.length} devices`);

    // Get notification icon and color based on event type
    const notificationConfig = getNotificationConfig(event_type);

    // Send to Firebase Cloud Messaging
    const fcmResponse = await fetch(
      "https://fcm.googleapis.com/fcm/send",
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${Deno.env.get("FCM_SERVER_KEY")}`,
        },
        body: JSON.stringify({
          registration_ids: fcmTokens,
          notification: {
            title: title,
            body: body,
            icon: notificationConfig.icon,
            color: notificationConfig.color,
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          data: {
            booking_id: booking_id,
            event_type: event_type,
            field_name: booking.footballFieldName,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            type: "recording_update",
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "recording_updates",
              priority: "high",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
                "content-available": 1,
              },
            },
          },
        }),
      }
    );

    const fcmResult = await fcmResponse.json();
    console.log("FCM Response:", JSON.stringify(fcmResult));

    // Log notification in database for tracking
    await supabaseClient.from("notification_logs").insert({
      booking_id: booking_id,
      event_type: event_type,
      title: title,
      body: body,
      user_ids: userIds,
      device_count: fcmTokens.length,
      fcm_response: fcmResult,
    });

    return new Response(
      JSON.stringify({ 
        success: true, 
        notified_users: userIds.length,
        devices_reached: fcmTokens.length,
        fcm_success: fcmResult.success || 0,
        fcm_failure: fcmResult.failure || 0
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

function getNotificationConfig(eventType: string): { icon: string; color: string } {
  switch (eventType) {
    case "recording_started":
      return { icon: "ic_recording", color: "#4CAF50" }; // Green
    case "recording_complete":
      return { icon: "ic_check", color: "#2196F3" }; // Blue
    case "recording_failed":
      return { icon: "ic_error", color: "#F44336" }; // Red
    case "processing_complete":
      return { icon: "ic_video", color: "#9C27B0" }; // Purple
    default:
      return { icon: "ic_notification", color: "#00BF63" }; // Brand green
  }
}



// Deno-specific imports. These should resolve in the Supabase Edge Function environment.
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders } from '../_shared/cors.ts';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL');
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

interface UpdatePayload {
  routeStopId: string;
  orderId?: string;
  newStatus: 'completed' | 'failed' | 'skipped'; // Enforce specific statuses
  actualArrivalTime?: string; // ISO 8601 string
  driverLatitude?: number;
  driverLongitude?: number;
  failureReason?: string;
}

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
    console.error('Missing Supabase environment variables');
    return new Response(JSON.stringify({ error: 'Server configuration error.' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500,
    });
  }

  try {
    const payload: UpdatePayload = await req.json();
    const supabaseClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const now = new Date().toISOString();

    // Validate payload
    if (!payload.routeStopId || !payload.newStatus) {
      return new Response(JSON.stringify({ error: 'Missing routeStopId or newStatus.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400,
      });
    }

    // 1. Update the RouteStop
    const routeStopUpdate: any = {
      status: payload.newStatus,
      actual_arrival_time: payload.actualArrivalTime || now,
      // Departure time could be set here or when driver starts moving to next stop
      // For simplicity, we can set it to now as well, or slightly after arrival.
      departure_time: now, 
    };
    if (payload.newStatus === 'failed' && payload.failureReason) {
      // You might want a specific column for failure_reason in route_stops
      // routeStopUpdate.failure_reason = payload.failureReason; 
      console.log(`Route stop ${payload.routeStopId} failed: ${payload.failureReason}`);
    }

    const { data: updatedRouteStop, error: routeStopError } = await supabaseClient
      .from('route_stops')
      .update(routeStopUpdate)
      .eq('id', payload.routeStopId)
      .select('id, delivery_route_id, order_id, sequence_number, type')
      .single();

    if (routeStopError) throw routeStopError;
    if (!updatedRouteStop) {
      return new Response(JSON.stringify({ error: 'Route stop not found or update failed.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 404,
      });
    }

    // 2. If it's a customer delivery stop and status is 'completed' or 'failed', update the Order
    if (updatedRouteStop.type === 'customer_delivery' && updatedRouteStop.order_id) {
      if (payload.newStatus === 'completed') {
        const { error: orderError } = await supabaseClient
          .from('orders')
          .update({
            status: 'delivered', // Main order status
            delivery_status: 'delivered', // Specific delivery lifecycle status
            actual_delivery_time: payload.actualArrivalTime || now,
          })
          .eq('id', updatedRouteStop.order_id);
        if (orderError) console.error(`Error updating order ${updatedRouteStop.order_id} to delivered:`, orderError);
      } else if (payload.newStatus === 'failed') {
        const { error: orderError } = await supabaseClient
          .from('orders')
          .update({
            delivery_status: 'delivery_failed',
            // Optionally, update main order status to something like 'requires_attention'
          })
          .eq('id', updatedRouteStop.order_id);
        if (orderError) console.error(`Error updating order ${updatedRouteStop.order_id} to delivery_failed:`, orderError);
      }
    }

    // 3. Check if this was the last stop on the route (excluding the final return to store)
    //    or if all customer deliveries are done.
    const { data: remainingStops, error: remainingStopsError } = await supabaseClient
      .from('route_stops')
      .select('id, type, status')
      .eq('delivery_route_id', updatedRouteStop.delivery_route_id)
      .neq('status', 'completed')
      .neq('status', 'skipped'); // Consider 'failed' as also not pending

    if (remainingStopsError) throw remainingStopsError;

    const hasPendingCustomerDeliveries = remainingStops?.some(stop => stop.type === 'customer_delivery' && stop.status === 'pending');
    const isLastStoreStop = updatedRouteStop.type === 'store' && !hasPendingCustomerDeliveries && remainingStops?.every(s => s.type === 'store');


    if (!hasPendingCustomerDeliveries || isLastStoreStop) {
      // All customer deliveries are done, or the current stop is the final return to store.
      // Mark the delivery_routes as 'completed'.
      // Also, update the driver's status to 'online_idle' (is_online: true, current_route_id: null).

      const { data: deliveryRoute, error: deliveryRouteError } = await supabaseClient
        .from('delivery_routes')
        .update({
          status: 'completed',
          completed_at: now,
        })
        .eq('id', updatedRouteStop.delivery_route_id)
        .select('id, assigned_driver_id')
        .single();
      
      if (deliveryRouteError) console.error('Error completing delivery route:', deliveryRouteError);

      if (deliveryRoute && deliveryRoute.assigned_driver_id) {
        const { error: driverUpdateError } = await supabaseClient
          .from('drivers')
          .update({
            current_route_id: null, // Driver is now idle
            // is_online remains true unless explicitly set otherwise
            // Optionally update driver's last_known_location if payload includes it
            ...(payload.driverLatitude && payload.driverLongitude && {
                current_latitude: payload.driverLatitude,
                current_longitude: payload.driverLongitude,
                last_seen_at: now,
            })
          })
          .eq('id', deliveryRoute.assigned_driver_id);
        if (driverUpdateError) console.error('Error updating driver to idle:', driverUpdateError);
      }
    } else if (payload.driverLatitude && payload.driverLongitude && updatedRouteStop.delivery_route_id) {
        // If route is not yet complete, but we have location, update driver's location
        const {data: routeDriver} = await supabaseClient.from('delivery_routes').select('assigned_driver_id').eq('id', updatedRouteStop.delivery_route_id).single();
        if(routeDriver && routeDriver.assigned_driver_id){
            await supabaseClient.from('drivers').update({
                current_latitude: payload.driverLatitude,
                current_longitude: payload.driverLongitude,
                last_seen_at: now,
            }).eq('id', routeDriver.assigned_driver_id);
        }
    }


    return new Response(JSON.stringify({ message: 'Status updated successfully.', updatedRouteStopId: updatedRouteStop.id }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200,
    });

  } catch (error) {
    console.error('Error in updateOrderStatusOnDelivery:', error);
    return new Response(JSON.stringify({ error: error.message || 'Unknown server error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 500,
    });
  }
});

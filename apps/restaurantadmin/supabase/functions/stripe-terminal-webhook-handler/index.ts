import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { Stripe } from 'https://esm.sh/stripe@14.10.0';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
);

const webhookSecret = Deno.env.get('STRIPE_TERMINAL_WEBHOOK_SECRET');

const corsHeaders = {
  'Access-Control-Allow-Origin': '*', 
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const signature = req.headers.get('stripe-signature');
  const body = await req.text();

  if (!signature) {
    console.error('Webhook error: Missing stripe-signature header');
    return new Response(JSON.stringify({ error: 'Missing stripe-signature header' }), { 
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }
  if (!webhookSecret) {
    console.error('Webhook error: STRIPE_TERMINAL_WEBHOOK_SECRET is not set.');
    return new Response(JSON.stringify({ error: 'Webhook secret not configured.' }), { 
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(
        body, signature, webhookSecret, undefined, Stripe.createSubtleCryptoProvider()
    );
  } catch (err) {
    console.error(`Webhook signature verification failed: ${err.message}`);
    return new Response(JSON.stringify({ error: `Webhook error: ${err.message}` }), { 
        status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  let supabaseOrderId: string | undefined;
  let relevantPaymentIntentId: string | undefined;
  let eventDataObject: any = event.data.object; // Use 'any' for flexibility initially

  if (event.type.startsWith('payment_intent.')) {
    const pi = eventDataObject as Stripe.PaymentIntent;
    supabaseOrderId = pi.metadata?.supabase_order_id;
    relevantPaymentIntentId = pi.id;
  } else if (event.type.startsWith('terminal.reader.')) {
    const readerAction = eventDataObject as Stripe.Terminal.Reader;
    relevantPaymentIntentId = readerAction.action?.process_payment_intent?.payment_intent;
    // For terminal events, we MUST have the relevantPaymentIntentId to find the order
    if (relevantPaymentIntentId) {
      const { data: orderData, error: orderError } = await supabaseAdmin
        .from('orders')
        .select('id') // Select the order id which is our supabaseOrderId
        .eq('stripe_payment_intent_id', relevantPaymentIntentId)
        .maybeSingle();
      if (orderError) {
        console.error(`Webhook: DB error looking up order by PI ${relevantPaymentIntentId} for terminal event:`, orderError);
      } else if (orderData) {
        supabaseOrderId = orderData.id;
      } else {
        console.warn(`Webhook: terminal.reader event for PI ${relevantPaymentIntentId} but no matching order found by PI.`);
      }
    } else {
        console.warn(`Webhook: terminal.reader event received without a PaymentIntent ID in its action payload. Event ID: ${event.id}`);
    }
  }

  // If, after trying, we still don't have a supabaseOrderId for an event that needs it for DB update, log and exit.
  if (!supabaseOrderId) {
    console.warn(`Webhook event type ${event.type} for PI ${relevantPaymentIntentId || 'unknown'} could not be mapped to a Supabase Order ID. Event ID: ${event.id}`);
    return new Response(JSON.stringify({ received: true, message: 'Could not map event to Supabase Order ID.' }), { 
        status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  console.log(`Processing event: ${event.type}. Supabase Order ID: ${supabaseOrderId}. Relevant PI: ${relevantPaymentIntentId}`);

  try {
    switch (event.type) {
      case 'payment_intent.succeeded': {
        const { error } = await supabaseAdmin
          .from('orders')
          .update({ status: 'paid' })
          .eq('id', supabaseOrderId)
          .eq('stripe_payment_intent_id', relevantPaymentIntentId); // Ensure we match on PI as well

        if (error) {
          console.error(`DB Error (payment_intent.succeeded) Order ${supabaseOrderId}, PI ${relevantPaymentIntentId}:`, error);
          return new Response(JSON.stringify({ error: 'Database update failed for payment_intent.succeeded' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`Order ${supabaseOrderId} (PI: ${relevantPaymentIntentId}) updated to 'paid'.`);
        break;
      }
      case 'payment_intent.payment_failed': {
        const pi = eventDataObject as Stripe.PaymentIntent; // Re-cast for specific fields
        const lastPaymentError = pi.last_payment_error;
        const { error } = await supabaseAdmin
          .from('orders')
          .update({ status: 'failed' }) 
          .eq('id', supabaseOrderId)
          .eq('stripe_payment_intent_id', relevantPaymentIntentId);

        if (error) {
          console.error(`DB Error (payment_intent.payment_failed) Order ${supabaseOrderId}, PI ${relevantPaymentIntentId}:`, error);
          return new Response(JSON.stringify({ error: 'Database update failed for payment_intent.payment_failed' }), { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
        }
        console.log(`Order ${supabaseOrderId} (PI: ${relevantPaymentIntentId}) updated to 'failed'. Reason: ${lastPaymentError?.message}`);
        break;
      }
      case 'terminal.reader.action_succeeded': {
        // supabaseOrderId should be resolved by now if relevantPaymentIntentId was found
        if (!supabaseOrderId || !relevantPaymentIntentId) {
             console.warn(`Webhook: terminal.reader.action_succeeded for PI ${relevantPaymentIntentId || 'unknown'} - Supabase Order ID ${supabaseOrderId || 'unknown'} missing. Skipping DB update.`);
             break;
        }
        console.log(`Terminal reader action_succeeded for PI: ${relevantPaymentIntentId}, Order: ${supabaseOrderId}`);
        const { error } = await supabaseAdmin
          .from('orders')
          .update({ status: 'terminal_awaiting_card' })
          .eq('id', supabaseOrderId)
          .eq('stripe_payment_intent_id', relevantPaymentIntentId);

        if (error) {
          console.error(`DB Error (terminal.reader.action_succeeded) Order ${supabaseOrderId}, PI ${relevantPaymentIntentId}:`, error);
        } else {
          console.log(`Order ${supabaseOrderId} (PI: ${relevantPaymentIntentId}) status updated to 'terminal_awaiting_card'.`);
        }
        break;
      }
      case 'terminal.reader.action_failed': {
        if (!supabaseOrderId || !relevantPaymentIntentId) {
            console.warn(`Webhook: terminal.reader.action_failed for PI ${relevantPaymentIntentId || 'unknown'} - Supabase Order ID ${supabaseOrderId || 'unknown'} missing. Skipping DB update.`);
            break;
        }
        const readerAction = eventDataObject as Stripe.Terminal.Reader;
        console.log(`Terminal reader action_failed for PI: ${relevantPaymentIntentId}, Order: ${supabaseOrderId}. Reason: ${readerAction.action?.failure_message}`);
        const { error } = await supabaseAdmin
          .from('orders')
          .update({ status: 'terminal_action_failed' })
          .eq('id', supabaseOrderId)
          .eq('stripe_payment_intent_id', relevantPaymentIntentId);

        if (error) {
          console.error(`DB Error (terminal.reader.action_failed) Order ${supabaseOrderId}, PI ${relevantPaymentIntentId}:`, error);
        } else {
          console.log(`Order ${supabaseOrderId} (PI: ${relevantPaymentIntentId}) status updated to 'terminal_action_failed'.`);
        }
        break;
      }
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
  } catch (dbError) {
    console.error('Error processing webhook event and updating database:', dbError);
    return new Response(JSON.stringify({ error: 'Internal server error during webhook processing.' }), { 
        status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
    });
  }

  return new Response(JSON.stringify({ received: true }), { 
    status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
  });
});

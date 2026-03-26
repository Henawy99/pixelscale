import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { Stripe } from 'https://esm.sh/stripe@14.10.0'; // Use a specific version
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.3'; // Use a specific version

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16', // Stripe API version
  httpClient: Stripe.createFetchHttpClient(), // Recommended for Deno
});

const supabaseAdmin = createClient(
  Deno.env.get('SUPABASE_URL') ?? '',
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '' // Use service role key for admin operations
);

const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // Allows all origins. For production, specify your app's domain.
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS', // OPTIONS is needed for preflight requests
};

serve(async (req: Request) => {
  // Handle OPTIONS preflight request for CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method Not Allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  try {
    const { orderId, amount, currency } = await req.json();

    if (!orderId || !amount || !currency) {
      return new Response(JSON.stringify({ error: 'Missing required fields: orderId, amount, currency' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const terminalId = Deno.env.get('STRIPE_S700_TERMINAL_ID');
    if (!terminalId) {
        console.error('STRIPE_S700_TERMINAL_ID environment variable not set.');
        return new Response(JSON.stringify({ error: 'Terminal configuration error on server.' }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    // 1. Create a PaymentIntent
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // Amount in smallest currency unit (e.g., cents)
      currency: currency,
      payment_method_types: ['card_present'],
      capture_method: 'automatic',
      metadata: {
        supabase_order_id: orderId,
      },
    });

    // 2. Update the order in Supabase with the PaymentIntent ID and set status to 'processing_terminal'
    const { error: updateError } = await supabaseAdmin
      .from('orders')
      .update({
        stripe_payment_intent_id: paymentIntent.id,
        status: 'processing_terminal',
      })
      .eq('id', orderId);

    if (updateError) {
      console.error('Error updating order in Supabase (in create-terminal-payment-intent):', updateError); // More specific log
      // Potentially try to cancel the PaymentIntent if the DB update fails critically
      // await stripe.paymentIntents.cancel(paymentIntent.id);
      return new Response(JSON.stringify({ error: 'Failed to update order status after PI creation.', supabaseError: updateError.message }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    console.log(`Order ${orderId} updated with PI ${paymentIntent.id} and status 'processing_terminal' (in create-terminal-payment-intent)`); // ADDED THIS LOG

    // 3. Instruct the terminal to process the PaymentIntent
    try {
        await stripe.terminal.readers.processPaymentIntent(
            terminalId,
            { payment_intent: paymentIntent.id }
        );
    } catch (terminalError) {
        console.error('Error processing payment intent on terminal:', terminalError);
        await supabaseAdmin
            .from('orders')
            .update({ status: 'terminal_comms_failed' })
            .eq('id', orderId);
        return new Response(JSON.stringify({ error: 'Failed to send payment to terminal.', stripeError: terminalError.message }), {
            status: 500,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
    }

    return new Response(
      JSON.stringify({
        paymentIntentId: paymentIntent.id,
        status: paymentIntent.status,
        message: 'PaymentIntent created and sent to terminal.',
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  } catch (error) {
    console.error('Error in create-terminal-payment-intent function:', error);
    return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

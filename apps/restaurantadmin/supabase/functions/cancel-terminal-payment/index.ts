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

const corsHeaders = {
  'Access-Control-Allow-Origin': '*', // For production, specify your app's domain
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

  try {
    const { paymentIntentId, orderId } = await req.json();

    if (!paymentIntentId || !orderId) {
      return new Response(JSON.stringify({ error: 'Missing paymentIntentId or orderId' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    console.log(`Attempting to cancel PaymentIntent: ${paymentIntentId} for Order: ${orderId}`);

    // Attempt to cancel the PaymentIntent with Stripe
    // This will only succeed if the PaymentIntent has not yet been processed to a final state (e.g. succeeded, failed, requires_capture if manual).
    // If the payment is already on the reader and awaiting card, this might also clear the reader.
    let cancelledPaymentIntent;
    try {
      cancelledPaymentIntent = await stripe.paymentIntents.cancel(paymentIntentId);
    } catch (stripeError) {
      console.error(`Stripe error cancelling PaymentIntent ${paymentIntentId}:`, stripeError);
      // If Stripe fails to cancel (e.g., already processed), we still update our order status.
      // The webhook handler should eventually update to the final correct status from Stripe.
      // We mark it as 'cancellation_attempted' or similar.
      await supabaseAdmin
        .from('orders')
        .update({ status: 'terminal_cancel_failed_stripe' }) // Or a more descriptive status
        .eq('id', orderId);
      return new Response(JSON.stringify({ error: 'Stripe failed to cancel payment intent.', details: stripeError.message }), {
        status: 500, // Or 400 if it's a client error like PI already succeeded
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }
    
    // Update the order status in Supabase to 'cancelled' or 'terminal_cancelled'
    const { error: updateError } = await supabaseAdmin
      .from('orders')
      .update({ status: 'cancelled_terminal' }) // New status
      .eq('id', orderId);

    if (updateError) {
      console.error(`Error updating order ${orderId} to 'cancelled_terminal':`, updateError);
      // Even if DB update fails, Stripe cancellation was attempted/succeeded.
      // This state is a bit tricky; ideally, this would be a transaction.
    }

    // Also, attempt to clear the reader display if a payment was active on it.
    // This requires the terminal ID.
    const terminalId = Deno.env.get('STRIPE_S700_TERMINAL_ID');
    if (terminalId) {
      try {
        await stripe.terminal.readers.cancelAction(terminalId);
        console.log(`Cancel action sent to terminal ${terminalId}`);
      } catch (readerError) {
        console.warn(`Could not send cancelAction to reader ${terminalId}:`, readerError.message);
        // This is not a critical failure for the cancellation flow itself.
      }
    }


    return new Response(JSON.stringify({ 
        message: 'PaymentIntent cancellation attempted.', 
        paymentIntentStatus: cancelledPaymentIntent?.status 
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });

  } catch (error) {
    console.error('Error in cancel-terminal-payment function:', error);
    return new Response(JSON.stringify({ error: error.message || 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { corsHeaders } from '../_shared/cors.ts'

interface GeocodeRequest {
  street?: string;
  city?: string;
  postcode?: string;
  country?: string; // e.g., 'AT' for Austria, 'DE' for Germany
}

interface GeocodeResponse {
  latitude?: number;
  longitude?: number;
  error?: string;
}

serve(async (req: Request) => {
  // This is needed if you're planning to invoke your function from a browser.
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { street, city, postcode, country }: GeocodeRequest = await req.json();
    const apiKey = Deno.env.get('GOOGLE_GEOCODING_API_KEY');

    if (!apiKey) {
      console.error('GOOGLE_GEOCODING_API_KEY is not set in Supabase secrets.');
      return new Response(JSON.stringify({ error: 'Geocoding API key not configured.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 500,
      });
    }

    if (!street || !city || !postcode || !country) {
      return new Response(JSON.stringify({ error: 'Missing address components: street, city, postcode, and country are required.' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      });
    }

    // Construct the address string for the API
    // Example: "1600 Amphitheatre Parkway, Mountain View, CA, USA"
    // Adjust based on how Google API best takes your typical addresses
    const addressParts = [street, postcode, city, country].filter(part => part && part.trim() !== "").join(', ');
    const encodedAddress = encodeURIComponent(addressParts);
    
    const geocodingUrl = `https://maps.googleapis.com/maps/api/geocode/json?address=${encodedAddress}&key=${apiKey}`;

    console.log(`[geocode-address] Requesting geocoding for: ${addressParts}`);
    const geocodeRes = await fetch(geocodingUrl);
    const geocodeData = await geocodeRes.json();

    console.log(`[geocode-address] Google API Response Status: ${geocodeData.status}`);
    // console.log(`[geocode-address] Google API Response Data: ${JSON.stringify(geocodeData)}`);


    if (geocodeData.status === 'OK' && geocodeData.results && geocodeData.results.length > 0) {
      const location = geocodeData.results[0].geometry.location;
      const response: GeocodeResponse = {
        latitude: location.lat,
        longitude: location.lng,
      };
      console.log(`[geocode-address] Geocoding successful: Lat: ${location.lat}, Lng: ${location.lng}`);
      return new Response(JSON.stringify(response), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      });
    } else {
      console.error(`[geocode-address] Geocoding failed. Status: ${geocodeData.status}, Error: ${geocodeData.error_message || 'No results'}`);
      return new Response(JSON.stringify({ error: `Geocoding failed: ${geocodeData.status} - ${geocodeData.error_message || 'No results found'}` }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 404, // Or 500 if it's an API issue
      });
    }
  } catch (error) {
    console.error('[geocode-address] Internal error:', error);
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    });
  }
})

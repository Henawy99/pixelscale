#!/bin/bash

# =====================================================
# TEST EDGE FUNCTION MANUALLY
# =====================================================
# This triggers the Edge Function directly to test it
# =====================================================

echo "🧪 Testing Edge Function manually..."
echo ""

curl -X POST \
  'https://upooyypqhftzzwjrfyra.supabase.co/functions/v1/process-admin-notifications' \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVwb295eXBxaGZ0enp3anJmeXJhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyOTQ0OTA1OSwiZXhwIjoyMDQ1MDI1MDU5fQ.XpBCZ8TH-FuEDhU8q1RsFx-x21qYW5svL80Ey3r-zQo" \
  -H "Content-Type: application/json" \
  -d '{}'

echo ""
echo ""
echo "✅ Done! Check the response above."
echo "If you see 'success: true', go check your ADMIN app!"
echo ""


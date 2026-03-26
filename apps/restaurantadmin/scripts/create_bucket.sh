#!/bin/bash

# Create 'menus' storage bucket in Supabase
cd "$(dirname "$0")/.."

# Load .env variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

echo "🪣 Creating 'menus' storage bucket in Supabase..."

# Create bucket
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/storage/v1/bucket" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "menus",
    "name": "menus",
    "public": true,
    "file_size_limit": 10485760,
    "allowed_mime_types": ["text/html", "text/css", "application/javascript", "image/jpeg", "image/png"]
  }')

echo "Response: $RESPONSE"
echo ""

if echo "$RESPONSE" | grep -q "already exists\|Duplicate"; then
    echo "✅ Bucket 'menus' already exists!"
else
    echo "✅ Bucket 'menus' created successfully!"
fi

echo ""
echo "Next: Run ./scripts/upload_menu.sh to upload your menu"



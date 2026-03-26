#!/bin/bash

SUPABASE_URL="https://iluhlynzkgubtaswvgwt.supabase.co"
SUPABASE_ANON_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml3aWFmemJhdndzeGZheHd6bmxjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzI4Mjk5NTUsImV4cCI6MjA0ODQwNTk1NX0.Y8r7-A0fgYCQVy8lWCbXxvmQJMh_SxVJODUgb8h56wY"
FILE_PATH="scripts/menu.html"
BUCKET_NAME="menus"
FILE_NAME="menu.html"

echo "📤 Uploading menu to Supabase Storage..."
echo "Bucket: $BUCKET_NAME"
echo "File: $FILE_NAME"

# First, try to delete the old file if it exists (ignore errors)
curl -s -X DELETE "$SUPABASE_URL/storage/v1/object/$BUCKET_NAME/$FILE_NAME" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" > /dev/null 2>&1

# Upload the file
RESPONSE=$(curl -s -X POST "$SUPABASE_URL/storage/v1/object/$BUCKET_NAME/$FILE_NAME" \
  -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: text/html; charset=utf-8" \
  -H "Cache-Control: max-age=3600" \
  --data-binary "@$FILE_PATH")

echo "Response: $RESPONSE"

PUBLIC_URL="$SUPABASE_URL/storage/v1/object/public/$BUCKET_NAME/$FILE_NAME"

if echo "$RESPONSE" | grep -q '"Key":\|"Id":'; then
  echo ""
  echo "✅ Upload complete!"
  echo "🌐 Public URL: $PUBLIC_URL"
  echo ""
  echo "🎉 Your menu is now live!"
  echo "   Open this URL: $PUBLIC_URL"
else
  echo ""
  echo "❌ Upload failed. Response:"
  echo "$RESPONSE"
fi

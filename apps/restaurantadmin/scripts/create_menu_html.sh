#!/bin/bash

# Quick bash script to generate and upload menu HTML
# This reads from .env file

cd "$(dirname "$0")/.."

# Load .env variables
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

BRAND_ID="4446a388-aaa7-402f-be4d-b82b23797415"

echo "🍔 Fetching DEVILS SMASH BURGER menu from Supabase..."
echo "Using Supabase URL: $SUPABASE_URL"

# Fetch categories and items using curl
CATEGORIES_JSON=$(curl -s -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    "$SUPABASE_URL/rest/v1/menu_categories?brand_id=eq.$BRAND_ID&order=display_order.asc&select=*")

ITEMS_JSON=$(curl -s -H "apikey: $SUPABASE_ANON_KEY" \
    -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
    "$SUPABASE_URL/rest/v1/menu_items?brand_id=eq.$BRAND_ID&order=display_order.asc&select=*")

echo "$CATEGORIES_JSON" > scripts/temp_categories.json
echo "$ITEMS_JSON" > scripts/temp_items.json

echo "✅ Data fetched successfully!"
echo "📊 Categories saved to: scripts/temp_categories.json"
echo "📊 Items saved to: scripts/temp_items.json"
echo ""
echo "Now run: dart run scripts/build_menu_html.dart"



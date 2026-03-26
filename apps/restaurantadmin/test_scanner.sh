#!/bin/bash
# Quick test script for scan-receipt edge function

# Create a simple test image (1x1 white pixel PNG in base64)
TEST_IMAGE="iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="

# Edge function URL
EDGE_URL="https://iluhlynzkgubtaswvgwt.supabase.co/functions/v1/scan-receipt"

# Your scanner secret (set this or use env var)
SCANNER_SECRET="${SCANNER_SECRET:-your_scanner_secret_here}"

# Supabase anon key
ANON_KEY="${SUPABASE_ANON_KEY:-eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlsdWhseW56a2d1YnRhc3d2Z3d0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzQ2NDA2MDEsImV4cCI6MjA1MDIxNjYwMX0.dQiMzAzLXbEjcLOHi7bMHMJO_pJlpvQ8Y8n6eErjVLI}"

echo "Testing scan-receipt edge function..."
echo "URL: $EDGE_URL"
echo ""

curl -X POST "$EDGE_URL" \
  -H "Content-Type: application/json" \
  -H "apikey: $ANON_KEY" \
  -H "Authorization: Bearer $ANON_KEY" \
  -H "X-Scanner-Secret: $SCANNER_SECRET" \
  -d "{\"receiptImageBase64\": \"$TEST_IMAGE\", \"brandName\": \"DEVILS SMASH BURGER\"}" \
  2>/dev/null | python3 -m json.tool 2>/dev/null || cat

echo ""
echo "Done!"

#!/bin/bash

MENU_URL="https://iluhlynzkgubtaswvgwt.supabase.co/storage/v1/object/public/menus/menu.html"
OUTPUT_FILE="scripts/menu_qr_code.png"
QR_API="https://api.qrserver.com/v1/create-qr-code/?size=1000x1000&data=$MENU_URL&color=DC143C&bgcolor=000000"

echo "🎯 Generating QR Code for DEVILS SMASH BURGER Menu..."
echo "URL: $MENU_URL"
echo ""
echo "📥 Downloading QR code..."
curl -s -o "$OUTPUT_FILE" "$QR_API"

if [ -f "$OUTPUT_FILE" ]; then
  echo "✅ QR Code saved to: $OUTPUT_FILE"
  echo ""
  echo "📱 QR Code Details:"
  echo "   - Size: 1000x1000 pixels (high resolution)"
  echo "   - Colors: Red on black (DEVILS brand colors)"
  echo "   - Format: PNG"
  echo ""
  echo "🖨️  Ready to print!"
  echo ""
  echo "To open the QR code:"
  echo "   open $OUTPUT_FILE"
else
  echo "❌ Failed to generate QR code."
fi

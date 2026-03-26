#!/bin/bash

echo "🔍 Checking Keystore Fingerprints"
echo "=================================="
echo ""

echo "📌 Google Play expects this SHA1:"
echo "   43:B6:03:E8:B4:B5:34:1C:F4:C8:E5:D2:A9:E4:2F:D3:35:4B:7C:2A"
echo ""

echo "🔑 Checking OLD keystore: upload-keystore.jks"
echo "Enter password for OLD keystore (try: Playmaker2024!):"
keytool -list -v -keystore upload-keystore.jks 2>&1 | grep -A 5 "Certificate fingerprints" | head -6
echo ""

echo "🔑 Checking NEW keystore: upload-keystore-new.jks"
echo "Password: Playmaker2024!"
keytool -list -v -keystore upload-keystore-new.jks -storepass Playmaker2024! 2>&1 | grep -A 5 "Certificate fingerprints" | head -6
echo ""

echo "✅ If OLD keystore SHA1 matches Google Play's expected SHA1, use that one!"
echo "❌ If NEW keystore SHA1 matches what you uploaded, you need to reset upload key in Play Console"


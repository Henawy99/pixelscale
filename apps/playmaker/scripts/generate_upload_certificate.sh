#!/bin/bash

echo "🔑 Generating Upload Certificate for Play Console"
echo "================================================="
echo ""

cd /Users/youssefelhenawy/Documents/playmakerstart

# Generate certificate
keytool -export -rfc \
  -keystore upload-keystore-new.jks \
  -alias upload \
  -file upload_certificate.pem \
  -storepass Playmaker2024!

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Certificate generated successfully!"
    echo ""
    echo "📦 File location:"
    echo "   $(pwd)/upload_certificate.pem"
    echo ""
    echo "📋 File contents preview:"
    head -3 upload_certificate.pem
    echo "   ..."
    echo ""
    echo "🚀 Next steps:"
    echo "   1. Go to: https://play.google.com/console"
    echo "   2. Select your app: Playmaker"
    echo "   3. Go to: Setup → App Integrity"
    echo "   4. Click: 'Request upload key reset'"
    echo "   5. Upload this file: upload_certificate.pem"
    echo ""
    echo "   Read full guide: UPLOAD_KEY_RESET_GUIDE.md"
    echo ""
else
    echo ""
    echo "❌ Certificate generation failed!"
    echo "Please check the error messages above."
fi


#!/bin/bash

# Ball Tracking Modal Deployment Script

set -e

echo "⚽ Ball Tracking GPU Function Deployment"
echo "========================================"
echo ""

# Check if Modal is installed (FastAPI is now handled in the cloud/image)
if ! python3 -c "import modal" &> /dev/null; then
    echo "📦 Installing Modal CLI..."
    python3 -m pip install modal --break-system-packages
fi

# Check if authenticated
if ! modal token list &> /dev/null; then
    echo "🔑 Please authenticate with Modal..."
    modal token new
fi

echo "🚀 Deploying ball tracking processor..."
modal deploy ball_tracking_processor.py

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Copy the webhook URL from above"
echo "2. Update lib/services/ball_tracking_service.dart with the webhook URL"
echo "3. Update the callback URL with your Supabase project URL"
echo "4. Run 'flutter pub get' to update dependencies"
echo "5. Test by uploading a short video in the Admin app"
echo ""
echo "📖 Full setup guide: ../BALL_TRACKING_SETUP.md"








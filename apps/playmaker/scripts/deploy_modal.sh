#!/bin/bash

# 🚀 Deploy Playmaker Ball Tracking to Modal.com
# This script sets up and deploys your ball tracking GPU processor

set -e  # Exit on error

echo "🎯 Playmaker Ball Tracking - Modal.com Deployment"
echo "=================================================="
echo ""

# Add user's local bin to PATH (where pip installs with --user)
export PATH="$HOME/.local/bin:$PATH"

# Check if Modal is installed
if ! command -v modal &> /dev/null; then
    echo "📦 Modal CLI not found. Installing..."
    echo "   (Using --break-system-packages for Python 3.13 compatibility)"
    pip3 install --break-system-packages modal
    echo ""
    echo "✅ Modal installed successfully"
else
    echo "✅ Modal CLI is installed"
fi

echo ""

# Check if authenticated
if ! modal token check &> /dev/null; then
    echo "🔐 You need to authenticate with Modal"
    echo "Opening browser for authentication..."
    modal token new
else
    echo "✅ Already authenticated with Modal"
fi

echo ""

# Check if secret exists
echo "🔐 Checking Supabase secret..."
if modal secret list | grep -q "playmaker-supabase"; then
    echo "✅ Supabase secret already exists"
    read -p "Do you want to update it? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter your Supabase credentials:"
        read -p "Supabase URL: " SUPABASE_URL
        read -p "Supabase Service Role Key: " SUPABASE_KEY
        modal secret create playmaker-supabase \
            SUPABASE_URL="$SUPABASE_URL" \
            SUPABASE_SERVICE_KEY="$SUPABASE_KEY"
        echo "✅ Secret updated"
    fi
else
    echo "⚠️  Supabase secret not found. Let's create it!"
    echo ""
    echo "You'll need:"
    echo "  1. Supabase URL: https://YOUR_PROJECT.supabase.co"
    echo "  2. Service Role Key: Found in Supabase Dashboard → Settings → API"
    echo ""
    read -p "Supabase URL: " SUPABASE_URL
    read -p "Supabase Service Role Key: " SUPABASE_KEY
    
    modal secret create playmaker-supabase \
        SUPABASE_URL="$SUPABASE_URL" \
        SUPABASE_SERVICE_KEY="$SUPABASE_KEY"
    
    echo "✅ Secret created"
fi

echo ""
echo "🚀 Deploying to Modal.com..."
echo ""

# Deploy the app
modal deploy modal_app.py

echo ""
echo "======================================================"
echo "✅ Deployment Complete!"
echo "======================================================"
echo ""
echo "📝 Next Steps:"
echo ""
echo "1. Copy the webhook URL from above (looks like:)"
echo "   https://your-username--playmaker-ball-tracking-trigger-job.modal.run"
echo ""
echo "2. Update lib/services/ball_tracking_service.dart:"
echo "   Find: static const String _modalWebhookUrl = 'YOUR_MODAL_WEBHOOK_URL_HERE';"
echo "   Replace with your actual webhook URL"
echo ""
echo "3. Test it:"
echo "   ./run_admin_app.sh"
echo "   Go to Ball Tracking Lab → Upload a video"
echo ""
echo "4. Monitor logs:"
echo "   modal app logs playmaker-ball-tracking --follow"
echo ""
echo "📚 Full guide: MODAL_DEPLOYMENT_GUIDE.md"
echo ""
echo "🎉 Happy tracking! 🚀⚽"


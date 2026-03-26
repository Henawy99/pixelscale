#!/bin/bash
# Deploy Auto-Compression Update to Modal Backend

echo "🚀 Deploying Auto-Compression Update to Modal.com"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if modal is installed
if ! command -v modal &> /dev/null; then
    echo "❌ Error: Modal CLI not installed"
    echo ""
    echo "Install it with:"
    echo "  pip install modal"
    echo ""
    exit 1
fi

echo "✅ Modal CLI found"
echo ""

# Deploy
echo "📦 Deploying ball_tracking_processor.py..."
echo ""

cd modal_gpu_function

modal deploy ball_tracking_processor.py

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Deployment successful!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 Auto-compression is now active!"
    echo ""
    echo "What happens now:"
    echo "  1. Upload any video (web, mobile, or desktop)"
    echo "  2. Videos > 100MB automatically compress on server"
    echo "  3. Uses CRF 18 (visually lossless, no quality loss)"
    echo "  4. Saves 60-70% file size"
    echo ""
    echo "💡 Tip: Mobile/desktop apps compress BEFORE upload (faster!)"
    echo ""
else
    echo ""
    echo "❌ Deployment failed!"
    echo ""
    echo "Check the error above and try again."
    exit 1
fi


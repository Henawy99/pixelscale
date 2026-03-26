#!/bin/bash

echo "🚀 Deploying Updated Modal App with GPU Fix"
echo "==========================================="
echo ""

# Check if modal CLI is installed
if ! command -v modal &> /dev/null; then
    echo "❌ Modal CLI not found. Installing..."
    pip3 install --break-system-packages modal
    export PATH="$HOME/.local/bin:$PATH"
fi

# Authenticate (if needed)
echo "🔐 Checking Modal authentication..."
modal token set --token-id your-token-id --token-secret your-token-secret 2>/dev/null || echo "Already authenticated"

# Navigate to the Modal app directory
cd "$(dirname "$0")/modal_gpu_function"

echo ""
echo "📦 Deploying Modal app..."
echo ""

# Deploy the app
modal deploy ball_tracking_processor.py

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🎯 Key Changes:"
echo "   ✅ GPU: Explicitly set to A100 (modal.gpu.A100())"
echo "   ✅ Timeout: Increased to 2 hours (7200 seconds)"
echo "   ✅ CPU: 4 cores for faster preprocessing"
echo "   ✅ Memory: 16GB RAM"
echo "   ✅ Custom script support: Added exec() for custom scripts"
echo "   ✅ Webhook: Now passes custom_script parameter"
echo ""
echo "🔥 Your next video upload will use the A100 GPU!"
echo ""


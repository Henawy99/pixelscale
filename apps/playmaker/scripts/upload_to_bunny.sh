#!/bin/bash

# Bunny Stream Upload Script
# Usage: ./upload_to_bunny.sh /path/to/video.mp4

VIDEO_PATH="$1"
API_KEY="013dea8a-2133-423f-9c66fc6b67e5-7790-4947"
LIBRARY_ID="561997"
CDN_HOSTNAME="vz-a24cd70f-fd2.b-cdn.net"

if [ -z "$VIDEO_PATH" ]; then
    echo "❌ Usage: ./upload_to_bunny.sh /path/to/video.mp4"
    exit 1
fi

if [ ! -f "$VIDEO_PATH" ]; then
    echo "❌ File not found: $VIDEO_PATH"
    exit 1
fi

FILENAME=$(basename "$VIDEO_PATH")
TITLE="${FILENAME%.*}"

echo "🐰 Bunny Stream Upload"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   File: $FILENAME"
echo "   Size: $(du -h "$VIDEO_PATH" | cut -f1)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: Create video entry
echo ""
echo "📝 Step 1: Creating video entry..."
RESPONSE=$(curl -s -X POST "https://video.bunnycdn.com/library/$LIBRARY_ID/videos" \
    -H "AccessKey: $API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"$TITLE\"}")

VIDEO_ID=$(echo "$RESPONSE" | grep -o '"guid":"[^"]*"' | cut -d'"' -f4)

if [ -z "$VIDEO_ID" ]; then
    echo "❌ Failed to create video entry: $RESPONSE"
    exit 1
fi

echo "   Video ID: $VIDEO_ID"

# Step 2: Upload video file
echo ""
echo "📤 Step 2: Uploading video (this may take a while)..."
UPLOAD_RESPONSE=$(curl -X PUT "https://video.bunnycdn.com/library/$LIBRARY_ID/videos/$VIDEO_ID" \
    -H "AccessKey: $API_KEY" \
    -H "Content-Type: application/octet-stream" \
    --data-binary "@$VIDEO_PATH" \
    --progress-bar 2>&1)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Upload Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📎 Your streaming links:"
echo ""
echo "   🎬 Direct MP4 (for sharing):"
echo "   https://$CDN_HOSTNAME/$VIDEO_ID/play_720p.mp4"
echo ""
echo "   📺 HLS Stream (adaptive quality):"
echo "   https://$CDN_HOSTNAME/$VIDEO_ID/playlist.m3u8"
echo ""
echo "   🖼️ Thumbnail:"
echo "   https://$CDN_HOSTNAME/$VIDEO_ID/thumbnail.jpg"
echo ""
echo "⚠️  Note: Video is being transcoded. It may take a few minutes to be playable."
echo ""

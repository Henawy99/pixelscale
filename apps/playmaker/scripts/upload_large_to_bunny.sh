#!/bin/bash

# Bunny Stream Upload Script for LARGE files (uses TUS protocol)
# Usage: ./upload_large_to_bunny.sh /path/to/video.mp4

VIDEO_PATH="$1"
API_KEY="013dea8a-2133-423f-9c66fc6b67e5-7790-4947"
LIBRARY_ID="561997"

if [ -z "$VIDEO_PATH" ]; then
    echo "❌ Usage: ./upload_large_to_bunny.sh /path/to/video.mp4"
    exit 1
fi

if [ ! -f "$VIDEO_PATH" ]; then
    echo "❌ File not found: $VIDEO_PATH"
    exit 1
fi

FILENAME=$(basename "$VIDEO_PATH")
TITLE="${FILENAME%.*}"
FILESIZE=$(stat -f%z "$VIDEO_PATH" 2>/dev/null || stat -c%s "$VIDEO_PATH")
FILESIZE_MB=$((FILESIZE / 1024 / 1024))

echo "🐰 Bunny Stream Large File Upload (TUS)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   File: $FILENAME"
echo "   Size: ${FILESIZE_MB} MB"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Step 1: Create video entry and get TUS upload URL
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

# Step 2: Create TUS upload
echo ""
echo "📤 Step 2: Initializing TUS upload..."
TUS_RESPONSE=$(curl -s -I -X POST "https://video.bunnycdn.com/tusupload" \
    -H "AuthorizationSignature: $API_KEY" \
    -H "AuthorizationExpire: 9999999999" \
    -H "VideoId: $VIDEO_ID" \
    -H "LibraryId: $LIBRARY_ID" \
    -H "Tus-Resumable: 1.0.0" \
    -H "Upload-Length: $FILESIZE" \
    -H "Upload-Metadata: filetype $(echo -n "video/mp4" | base64),title $(echo -n "$TITLE" | base64)" 2>&1)

# Get the Location header
UPLOAD_URL=$(echo "$TUS_RESPONSE" | grep -i "^location:" | tr -d '\r' | cut -d' ' -f2)

if [ -z "$UPLOAD_URL" ]; then
    echo "❌ Failed to create TUS upload session"
    echo "Response: $TUS_RESPONSE"
    
    # Fallback to direct upload
    echo ""
    echo "⚠️ Falling back to direct upload (may take longer)..."
    
    # Upload with progress bar
    curl -X PUT "https://video.bunnycdn.com/library/$LIBRARY_ID/videos/$VIDEO_ID" \
        -H "AccessKey: $API_KEY" \
        -H "Content-Type: application/octet-stream" \
        --data-binary "@$VIDEO_PATH" \
        --progress-bar
    
    echo ""
else
    echo "   Upload URL: $UPLOAD_URL"
    
    # Step 3: Upload file in chunks using TUS
    echo ""
    echo "📤 Step 3: Uploading file (this may take a while for large files)..."
    
    curl -X PATCH "$UPLOAD_URL" \
        -H "AuthorizationSignature: $API_KEY" \
        -H "AuthorizationExpire: 9999999999" \
        -H "VideoId: $VIDEO_ID" \
        -H "LibraryId: $LIBRARY_ID" \
        -H "Tus-Resumable: 1.0.0" \
        -H "Upload-Offset: 0" \
        -H "Content-Type: application/offset+octet-stream" \
        --data-binary "@$VIDEO_PATH" \
        --progress-bar
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Upload Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📎 Your streaming link:"
echo ""
echo "   🎬 SHARE THIS LINK:"
echo "   https://iframe.mediadelivery.net/play/$LIBRARY_ID/$VIDEO_ID"
echo ""
echo "⚠️ Transcoding a 3GB video takes 30-60 minutes. Check progress with:"
echo "   curl -s 'https://video.bunnycdn.com/library/$LIBRARY_ID/videos/$VIDEO_ID' -H 'AccessKey: $API_KEY' | grep encodeProgress"
echo ""

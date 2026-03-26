#!/bin/bash
# Video Compression Script for Ball Tracking
# Reduces file size by 60-80% while maintaining quality

if [ $# -eq 0 ]; then
    echo "❌ Error: No input file specified"
    echo ""
    echo "Usage: ./compress_video.sh input.mp4 [output.mp4]"
    echo ""
    echo "Example:"
    echo "  ./compress_video.sh Field2.MP4"
    echo "  ./compress_video.sh Field2.MP4 Field2_compressed.mp4"
    exit 1
fi

INPUT="$1"
OUTPUT="${2:-${INPUT%.*}_compressed.mp4}"

if [ ! -f "$INPUT" ]; then
    echo "❌ Error: Input file '$INPUT' not found"
    exit 1
fi

# Check if ffmpeg is installed
if ! command -v ffmpeg &> /dev/null; then
    echo "❌ Error: ffmpeg is not installed"
    echo ""
    echo "Install it with:"
    echo "  brew install ffmpeg"
    exit 1
fi

echo "🎬 Video Compression for Ball Tracking"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📹 Input:  $INPUT"
echo "📹 Output: $OUTPUT"
echo ""

# Get input file size
INPUT_SIZE=$(du -h "$INPUT" | cut -f1)
echo "📊 Original size: $INPUT_SIZE"
echo ""
echo "🔄 Compressing... (this may take a few minutes)"
echo ""

# Compress video
# - CRF 23: Good quality (18=high quality, 28=lower quality)
# - preset medium: Good balance of speed and compression
# - No audio: Ball tracking doesn't need audio
# - 720p max: Reduces size significantly, still good for YOLO detection
ffmpeg -i "$INPUT" \
  -vf "scale='min(1280,iw)':'min(720,ih)':force_original_aspect_ratio=decrease" \
  -c:v libx264 \
  -crf 23 \
  -preset medium \
  -an \
  -movflags +faststart \
  -y \
  "$OUTPUT"

if [ $? -eq 0 ]; then
    OUTPUT_SIZE=$(du -h "$OUTPUT" | cut -f1)
    echo ""
    echo "✅ Compression complete!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📊 Original:   $INPUT_SIZE"
    echo "📊 Compressed: $OUTPUT_SIZE"
    echo "📁 Output:     $OUTPUT"
    echo ""
    echo "💡 You can now upload '$OUTPUT' to the app!"
else
    echo ""
    echo "❌ Compression failed!"
    exit 1
fi





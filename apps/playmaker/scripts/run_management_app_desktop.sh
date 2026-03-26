#!/bin/bash

# ============================================
# Playmaker Management App - macOS Desktop
# ============================================
# Unified Admin + Partner app
# Best for video uploads and admin work!
# ============================================

echo "🖥️ Running Playmaker Management App (macOS Desktop)..."
echo "======================================================"
echo ""
echo "📱 This is the unified Admin + Partner app!"
echo "   - Login with admin email → Admin interface"
echo "   - Login with partner credentials → Partner interface"
echo ""
echo "✅ Benefits of Desktop version:"
echo "   - No CORS errors for video uploads"
echo "   - Better performance for large files"
echo "   - Native macOS experience"
echo ""

# Run the management app as desktop
flutter run -d macos -t lib/main_management.dart

echo ""
echo "✅ Management app (Desktop) session ended"

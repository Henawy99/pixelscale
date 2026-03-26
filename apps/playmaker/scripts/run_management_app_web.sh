#!/bin/bash

# ============================================
# Playmaker Management App - Chrome Web
# ============================================
# Unified Admin + Partner app
# ============================================

echo "🌐 Running Playmaker Management App (Chrome Web)..."
echo "================================================"
echo ""
echo "📱 This is the unified Admin + Partner app!"
echo "   - Login with admin email → Admin interface"
echo "   - Login with partner credentials → Partner interface"
echo ""

# Run the management app on Chrome
flutter run -d chrome -t lib/main_management.dart

echo ""
echo "✅ Management app (Web) session ended"

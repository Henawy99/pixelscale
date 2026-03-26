#!/bin/bash

# ============================================
# Playmaker Management App - Android Dev
# ============================================
# Unified Admin + Partner app
# Role determined by login credentials
# ============================================

echo "🚀 Running Playmaker Management App (Android)..."
echo "============================================"
echo ""
echo "📱 This is the unified Admin + Partner app!"
echo "   - Login with admin email → Admin interface"
echo "   - Login with partner credentials → Partner interface"
echo ""

# Run the management app on Android
flutter run -d emulator-5554 --flavor management -t lib/main_management.dart

echo ""
echo "✅ Management app session ended"

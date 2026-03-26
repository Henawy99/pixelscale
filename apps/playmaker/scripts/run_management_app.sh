#!/bin/bash

# ============================================
# Playmaker Management App - iOS Development
# ============================================
# Unified Admin + Partner app
# Role determined by login credentials
# ============================================

echo "🚀 Running Playmaker Management App (iOS)..."
echo "============================================"
echo ""
echo "📱 This is the unified Admin + Partner app!"
echo "   - Login with admin email → Admin interface"
echo "   - Login with partner credentials → Partner interface"
echo ""

# Generate management icons if needed
# flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_management.yaml 2>/dev/null || true

# Run the management app
flutter run -t lib/main_management.dart

echo ""
echo "✅ Management app session ended"

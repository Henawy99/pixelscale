#!/bin/bash

# =====================================================
# ADMIN NOTIFICATIONS - Complete Setup Script
# =====================================================
# Run this script to set up push notifications for new user signups
# =====================================================

set -e  # Exit on error

echo "🔔 Setting up ADMIN Push Notifications..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Change to project directory
cd /Users/youssefelhenawy/Documents/playmakerstart

echo -e "${BLUE}Step 1: Checking Supabase CLI...${NC}"
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Supabase CLI not found!${NC}"
    echo "Install it with: brew install supabase/tap/supabase"
    exit 1
fi
echo -e "${GREEN}✅ Supabase CLI found${NC}"
echo ""

echo -e "${BLUE}Step 2: Linking Supabase project...${NC}"
echo "If prompted, login to Supabase in your browser, then come back here."
supabase link --project-ref upooyypqhftzzwjrfyra
echo -e "${GREEN}✅ Project linked${NC}"
echo ""

echo -e "${BLUE}Step 3: Applying database migrations...${NC}"
supabase db push
echo -e "${GREEN}✅ Migrations applied${NC}"
echo ""

echo -e "${BLUE}Step 4: Setting Firebase credentials...${NC}"
FIREBASE_CREDS_FILE="/Users/youssefelhenawy/Documents/playmakerstart/playmaker-4af3d-firebase-adminsdk-bcwnf-7d40b91925.json"

if [ ! -f "$FIREBASE_CREDS_FILE" ]; then
    echo -e "${RED}❌ Firebase credentials file not found!${NC}"
    echo "Expected: $FIREBASE_CREDS_FILE"
    exit 1
fi

# Read the JSON file and set as secret (compatible with older CLI versions)
FIREBASE_CREDS=$(cat "$FIREBASE_CREDS_FILE" | tr -d '\n' | tr -d ' ')
supabase secrets set FIREBASE_CREDENTIALS="$FIREBASE_CREDS"
echo -e "${GREEN}✅ Firebase credentials set${NC}"
echo ""

echo -e "${BLUE}Step 5: Verifying secrets...${NC}"
supabase secrets list
echo ""

echo -e "${BLUE}Step 6: Deploying Edge Functions...${NC}"
supabase functions deploy process-admin-notifications
echo -e "${GREEN}✅ Edge functions deployed${NC}"
echo ""

echo -e "${BLUE}Step 7: Verifying deployment...${NC}"
supabase functions list
echo ""

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${YELLOW}⚠️  IMPORTANT NEXT STEPS:${NC}"
echo ""
echo "1. Set up the cron job in Supabase Dashboard:"
echo "   → Go to: https://supabase.com/dashboard/project/upooyypqhftzzwjrfyra/sql/new"
echo "   → Copy the SQL from ADMIN_NOTIFICATIONS_COMPLETE_FIX.md (Step 5)"
echo "   → Run it"
echo ""
echo "2. Build and install ADMIN app on your iPhone:"
echo "   → Run: flutter pub run flutter_launcher_icons:main -f flutter_launcher_icons_admin.yaml"
echo "   → Run: flutter build ios --release -t lib/main_admin.dart"
echo "   → Run: open ios/Runner.xcworkspace"
echo "   → Install on your iPhone from Xcode"
echo ""
echo "3. Login to ADMIN app with youssef@gmail.com"
echo ""
echo "4. Create a test user in USER app"
echo ""
echo "5. Wait 1 minute for notification! 🔔"
echo ""
echo -e "${GREEN}🎉 Follow the guide in ADMIN_NOTIFICATIONS_COMPLETE_FIX.md for details!${NC}"


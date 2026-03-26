#!/bin/bash
# Deploy Booking Notifications Update

echo "🚀 Deploying Booking Notifications"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Error: Supabase CLI not installed"
    echo ""
    echo "Install it with:"
    echo "  brew install supabase/tap/supabase"
    echo ""
    exit 1
fi

echo "✅ Supabase CLI found"
echo ""

# Deploy Edge Function
echo "📦 Deploying send-booking-notification Edge Function..."
echo ""

supabase functions deploy send-booking-notification

if [ $? -eq 0 ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✅ Edge Function deployed successfully!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "🎉 Booking notifications are now active!"
    echo ""
    echo "What happens now:"
    echo "  1. User creates a booking in USERAPP"
    echo "  2. Admin receives push notification 📲"
    echo "  3. Notification shows field, date, time, price"
    echo ""
    echo "💡 Test it:"
    echo "  1. Open USERAPP"
    echo "  2. Book a field"
    echo "  3. Check ADMIN app for notification"
    echo ""
else
    echo ""
    echo "❌ Deployment failed!"
    echo ""
    echo "Check the error above and try again."
    echo ""
    echo "Common issues:"
    echo "  • Not logged in: Run 'supabase login'"
    echo "  • Not linked: Run 'supabase link --project-ref <your-ref>'"
    echo "  • Wrong directory: Make sure you're in the project root"
    echo ""
    exit 1
fi





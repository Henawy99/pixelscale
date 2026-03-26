#!/bin/bash

# =====================================================
# Deploy All Notification Edge Functions
# =====================================================

echo "🚀 Deploying Notification Edge Functions..."
echo "============================================"
echo ""

PROJECT_REF="upooyypqhftzzwjrfyra"

# Deploy user notification function
echo "📲 Deploying send-user-notification..."
supabase functions deploy send-user-notification --project-ref $PROJECT_REF

# Deploy partner notification function  
echo "📲 Deploying send-partner-notification..."
supabase functions deploy send-partner-notification --project-ref $PROJECT_REF

# Deploy existing functions (ensure they're up to date)
echo "📲 Deploying send-booking-notification..."
supabase functions deploy send-booking-notification --project-ref $PROJECT_REF

echo "📲 Deploying send-admin-notification..."
supabase functions deploy send-admin-notification --project-ref $PROJECT_REF

echo "📲 Deploying send-booking-rejection-notification..."
supabase functions deploy send-booking-rejection-notification --project-ref $PROJECT_REF

echo ""
echo "============================================"
echo "✅ All notification functions deployed!"
echo ""
echo "📋 Deployed Functions:"
echo "   • send-user-notification (USER APP)"
echo "   • send-partner-notification (PARTNER APP)"
echo "   • send-booking-notification (ADMIN APP)"
echo "   • send-admin-notification (ADMIN APP)"
echo "   • send-booking-rejection-notification (USER APP)"
echo ""
echo "🗄️ Don't forget to create the partner_devices table!"
echo "   See NOTIFICATIONS_SETUP.md for SQL"
echo ""




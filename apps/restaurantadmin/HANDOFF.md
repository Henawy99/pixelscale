# HANDOFF.md - Project Handover for Claude Code

## Project Overview
This repository (`/Users/youssefelhenawy/Desktop/pixelscale/apps/restaurantadmin`) is a Flutter web/mobile Restaurant Admin & POS app integrated with Supabase. We have been implementing live multi-account order monitoring & ingestion for Lieferando (Takeaway.com) accounts into the POS system.

---

## 1. What Has Been Completed & Current State

### A. Architecture & Components
1. **Monitor & Session API:**
   - Located at: `~/Downloads/lieferando-multi-account/` (and local patched version in `tools/lieferando-monitor-patched.js` and `tools/lieferando-api-server.js`).
   - Uses Playwright persistent contexts (`profiles/account1`, etc.) to monitor Lieferando live orders via Takeaway.com's live orders API.
   - Session API server runs on port `3001` (`http://localhost:3001` or VPS IP `http://<IP>:3001`) with endpoints:
     - `GET /api/sessions`: Returns status of all configured accounts (Active/Expired, lastCheckedAt).
     - `POST /api/sessions/:id/relogin`: Launches manual login window.
     - `POST /api/sessions/:id/relogin-complete`: Resumes background monitoring.
   - The monitor intercepts orders matching `/live-orders-api\.takeaway\.com\/api\/orders/i` and includes status transitions like `kitchen`, `in_kitchen`, `new`, `pending`, `accepted`, `preparing`, etc.
   - Sends payload via webhook POST to Supabase Edge Function `receive-lieferando-order` with `Authorization: Bearer <SUPABASE_ANON_KEY>` and `apikey: <SUPABASE_ANON_KEY>`.

2. **Supabase Database & Edge Function:**
   - Edge Function: `supabase/functions/receive-lieferando-order/index.ts` (Project Ref: `iluhlynzkgubtaswvgwt`).
   - Columns added to `orders` table:
     - `customer_name` (TEXT)
     - `customer_phone` (TEXT)
     - `verification_code` (TEXT) - Lieferando phone masking/verification code (e.g. `504083954`)
     - `public_reference` (TEXT) - Short order code (e.g. `3FPDK7`)
     - `delivery_notes` (TEXT) - Customer floor/door notes
     - `platform_raw_data` (JSONB) - Complete raw payload from Lieferando API
     - `couriers` (JSONB)
     - `food_prep_duration` (INTEGER)
     - `with_alcohol` (BOOLEAN)
   - Columns added to `order_items` table:
     - `category_name` (TEXT)
     - `item_code` (TEXT)
     - `specifications` (JSONB)
     - `partner_product_ids` (JSONB)
     - `lieferando_product_id` (BIGINT)
     - `lieferando_menu_product_id` (TEXT)
     - `item_remarks` (TEXT)

3. **Flutter App:**
   - `lib/screens/delivery_sessions_screen.dart`: UI screen under "Platforms" tab displaying active/expired status for each Lieferando account, with a configurable Monitor API URL (saved locally) and re-login action sheet.
   - `lib/screens/main_screen.dart`: Tab navigation updated to include "Platforms".
   - Orders Realtime Listener: Listens for `status: 'pending_confirmation'` and displays the auto-confirm dialog.

---

## 2. Immediate Issues & Next Tasks Requested by User

In the most recent message, the user reported the following items that need to be resolved:

### Completed in this session:
1. ✅ **Brand Mapping Fixed**: Account 2 mapped to `TACOTASTIC` (`f5116077-8de3-488b-bf9d-75295f791dce`), Account 3 mapped to `CRISPY CHICKEN LAB` (`8ec82a94-89f5-4603-bb35-c47c78d66d2a`).
2. ✅ **Fulfillment Type Fixed**: Dynamic pickup vs delivery mapping (`o.delivery_type` -> `fulfillment_type: 'pickup'` vs `'delivery'`).
3. ✅ **Unit Price & Fees Fixed**: Unit price stored as unit price (`price_at_purchase = 5.90` for quantity 4 = 23.60 total line price), delivery fee and service fees properly parsed.
4. ✅ **Estimated Delivery Time Added**:
   - Stored in database (`estimated_delivery_time`, `estimated_pickup_time`).
   - Displayed on the main **Orders Screen** grid tiles as a green badge: `🕒 Est. Delivery: HH:mm`.
   - Displayed on the **Order Details Screen** under Order Information.
5. ✅ **Customer Direct Phone Number Added**:
   - Customer's direct phone number (`customer.phone_number`) displayed prominently.
   - Dual Call options provided:
     - Button 1: **Call via Gateway** (`+4314350148 #<verifyCode>`)
     - Button 2: **Call Direct** (`<customerPhone>`)
6. ✅ **Order Cancellation Bug Fixed**:
   - Created missing PostgreSQL RLS `UPDATE` policies on `orders` and `order_items`.
   - Cancellation in `OrderDetailScreen` now updates database status to `cancelled` without permission/update errors.
7. ✅ **Direct `confirmed` Status on Ingestion**:
   - Removed `pending_confirmation` so all newly fetched Lieferando orders immediately enter `confirmed` status without triggering confirmation prompts.
8. ✅ **Edge Function & Monitor Redeployed and Running**:
   - Function: `receive-lieferando-order` deployed to Supabase.
   - Monitor: Running live in background (`task-560`), monitoring Accounts 1, 2, and 3.

---

## 3. Key Files & Locations

- **Flutter App Workspace:** `/Users/youssefelhenawy/Desktop/pixelscale/apps/restaurantadmin`
  - `lib/screens/order_detail_screen.dart` (Order details display & call button)
  - `lib/screens/delivery_sessions_screen.dart` (Platforms session monitor UI)
  - `lib/models/order.dart` or equivalent order model (Ensure new fields are deserialized from Supabase)
  - `lib/services/lieferando_service.dart` (Monitor API client)
- **Supabase Edge Functions:**
  - `supabase/functions/receive-lieferando-order/index.ts`
  - Redeploy command: `npx supabase functions deploy receive-lieferando-order --project-ref iluhlynzkgubtaswvgwt`
- **Lieferando Monitor Project:**
  - `/Users/youssefelhenawy/Downloads/lieferando-multi-account/`
  - `tools/lieferando-monitor-patched.js` (canonical copy in repo)
  - `tools/lieferando-api-server.js` (canonical copy in repo)
  - Copy to monitor dir and run:
    `cp tools/lieferando-monitor-patched.js ~/Downloads/lieferando-multi-account/monitor.js`
    `node ~/Downloads/lieferando-multi-account/monitor.js`

---

## 4. Next Steps for Claude Code

1. Inspect `lib/screens/order_detail_screen.dart` and `lib/models/` to see how orders and items are represented and rendered.
2. Update `supabase/functions/receive-lieferando-order/index.ts`:
   - Fix brand mapping (`account2` -> `TACOTASTIC`, etc.).
   - Fix `fulfillment_type` mapping (`pickup` vs `delivery` from `delivery_type`).
   - Fix price mapping.
   - Deploy function with `npx supabase functions deploy receive-lieferando-order --project-ref iluhlynzkgubtaswvgwt`.
3. Update `tools/lieferando-monitor-patched.js` and copy to `~/Downloads/lieferando-multi-account/monitor.js`:
   - Update `accounts.config.json` with correct brand labels.
   - Ensure `delivery_type` and full raw data are passed cleanly.
4. Update `order_detail_screen.dart` in Flutter:
   - Add verification code, delivery notes, public reference, item specifications.
   - Add the direct dial button with `+4314350148#<verification_code>`.
5. Run & test:
   - Verify web app with `flutter run -d web-server --web-port 8080`.
   - Test webhook and verify order details screen.

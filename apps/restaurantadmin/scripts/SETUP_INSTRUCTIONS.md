# 🍔 DEVILS SMASH BURGER - Menu Setup Instructions

## Problem

Your menu HTML file is ready, but it needs to be uploaded to Supabase Storage so it can be accessed via a public URL and QR code.

## Solution: Manual Setup via Supabase Dashboard

Follow these steps **carefully**:

### Step 1: Create the Storage Bucket

1. Go to https://supabase.com/dashboard/project/iwiafzbavwsxfaxwznlc
2. Click on **Storage** in the left sidebar
3. Click the **"New bucket"** button (top right)
4. Enter these settings:
   - **Name**: `menus`
   - **Public bucket**: ✅ **ENABLE THIS** (very important!)
   - Leave other settings as default
5. Click **"Create bucket"**

### Step 2: Upload the Menu File

1. Click on the `menus` bucket you just created
2. Click the **"Upload file"** button
3. Select the file: `/Users/youssefelhenawy/Desktop/restaurantadmin/scripts/menu.html`
4. The file will upload with the name `menu.html`

### Step 3: Get the Public URL

After uploading, you'll see the file `menu.html` in the list.

The public URL will be:
```
https://iluhlynzkgubtaswvgwt.supabase.co/storage/v1/object/public/menus/menu.html
```

### Step 4: Test the Menu

1. Open the URL in your browser
2. You should see your beautiful menu with:
   - DEVILS SMASH BURGER logo
   - All menu items with images
   - Prices in EURO (€)
   - Auto-updating data from Supabase

### Step 5: Generate the QR Code

Once the menu loads correctly:

1. Run this command:
```bash
cd /Users/youssefelhenawy/Desktop/restaurantadmin
./scripts/generate_qr.sh
```

2. This will create a QR code image at:
   `scripts/menu_qr_code.png`

3. Open and print the QR code:
```bash
open scripts/menu_qr_code.png
```

## Troubleshooting

### If you see HTML source code instead of the rendered page:

This means the file isn't being served with the correct Content-Type. To fix:

1. In Supabase Dashboard, go to Storage > menus
2. Click the three dots (...) next to `menu.html`
3. Click **"Delete"**
4. Upload the file again
5. Make sure the bucket is set to **Public**

### If images don't load:

The menu fetches data from Supabase in real-time. Make sure:
- Your menu items have valid image URLs in the database
- The images are uploaded to Supabase Storage (not blob: URLs)

### If data doesn't update:

The menu automatically fetches fresh data each time it loads. Just refresh the page!

## What You Get

✅ **Clean URL**: `https://iluhlynzkgubtaswvgwt.supabase.co/storage/v1/object/public/menus/menu.html`

✅ **Auto-updating**: Menu fetches data from Supabase every time it loads

✅ **EURO prices**: All prices display with € symbol

✅ **DEVILS logo**: Your brand logo is embedded at the top

✅ **Mobile-friendly**: Responsive design works on all devices

✅ **QR code**: High-resolution QR code for printing

## Need Help?

If you still see issues after following these steps, check the browser console (F12) for any JavaScript errors.



# 🍔 DEVILS SMASH BURGER - Menu Website Setup Guide

## ✅ What's Ready

Your beautiful menu website HTML is generated at:
```
scripts/devils_menu.html
```

## 📋 Setup Steps

### Option 1: Host on Supabase Storage (Recommended)

1. **Create Storage Bucket** in Supabase Dashboard:
   - Go to: https://supabase.com/dashboard
   - Navigate to: Storage → Create a new bucket
   - Bucket name: `menus`
   - Make it **Public** ✅
   - Click "Create bucket"

2. **Upload the Menu File**:
   - Click on the `menus` bucket
   - Click "Upload file"
   - Select: `scripts/devils_menu.html`
   - Rename it to: `devils-menu.html` (optional, but cleaner URL)
   - Click "Upload"

3. **Get the Public URL**:
   - After upload, click on the file
   - Copy the public URL (it will look like):
   ```
   https://iluhlynzkgubtaswvgwt.supabase.co/storage/v1/object/public/menus/devils-menu.html
   ```

### Option 2: Host on Any Web Server

Just upload `scripts/devils_menu.html` to any web hosting service:
- GitHub Pages (free)
- Netlify (free)
- Vercel (free)
- Your own web server

---

## 📱 Generate QR Code

Once you have the URL, generate a QR code:

### Method 1: Online QR Generator (Easiest)
1. Visit: **https://www.qr-code-generator.com/**
2. Paste your menu URL
3. Customize the design (optional):
   - Add your logo
   - Change colors to match your brand (red/black)
   - Add a frame with text like "SCAN FOR MENU"
4. Download as high-resolution PNG
5. Print it!

### Method 2: Free QR Code Services
- https://www.qrcode-monkey.com/ (no watermark, free)
- https://www.qr-code-generator.com/ (professional looking)
- https://goqr.me/ (simple and fast)

### Method 3: Using API (Instant)
Visit this URL in your browser (replace YOUR_MENU_URL):
```
https://api.qrserver.com/v1/create-qr-code/?size=500x500&data=YOUR_MENU_URL
```

---

## 🎨 Design Tips for Your QR Code

**For Best Results:**
- **Size**: At least 500x500 pixels for printing
- **Colors**: Use your brand colors (red/black)
- **Frame**: Add text like "SCAN FOR MENU" or "🔥 VIEW OUR MENU"
- **Logo**: Consider adding your restaurant logo in the center
- **Test**: Always test the QR code before printing!

---

## 📍 Where to Display Your QR Code

**Recommended Locations:**
- 🪟 **Window decals** - Visible from outside
- 🪑 **Table tents** - On every table
- 🧾 **Receipts** - Include it on printed receipts
- 📄 **Flyers** - Hand out with orders
- 🖼️ **Posters** - At the entrance
- 📱 **Social media** - Share on Instagram/Facebook

---

## 🔄 Updating Your Menu

When you add/remove/update items:

1. **Run the scripts again**:
   ```bash
   ./scripts/create_menu_html.sh
   dart run scripts/build_menu_html.dart
   ```

2. **Re-upload** to Supabase Storage (overwrite the existing file)

3. **No need to change the QR code!** 
   - Same URL = Same QR code
   - Customers always see the latest menu ✨

---

## 🎉 Your Menu is Ready!

Your menu features:
- ✅ 51 delicious items
- ✅ 5 categories (Burger, Saucen, Desserts, Drinks, Appetizers)
- ✅ Beautiful modern design
- ✅ Mobile-responsive
- ✅ Fast loading
- ✅ Professional look

**Need help?** Check your generated menu by opening:
```
scripts/devils_menu.html
```
in any web browser to preview it!

---

Made with ❤️ for DEVILS SMASH BURGER 🔥



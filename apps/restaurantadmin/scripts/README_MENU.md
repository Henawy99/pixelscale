# 🔥 DEVILS SMASH BURGER - Menu Website & QR Code

## ✅ What's Been Created

### 1. **Beautiful Menu Website** 🌐
- **File**: `scripts/devils_menu.html`
- **Features**:
  - 51 menu items across 5 categories
  - Modern, slick design with red/black theme
  - Mobile-responsive
  - Animated scroll effects
  - Professional food presentation

### 2. **QR Code** 📱
- **File**: `scripts/devils_menu_qr_code.png`
- **Specs**:
  - 1000x1000 pixels (high resolution for printing)
  - Red on black (brand colors)
  - Ready to print

---

## 🚀 Next Steps to Go Live

### Step 1: Create Supabase Storage Bucket

1. Go to your Supabase Dashboard: https://supabase.com/dashboard
2. Navigate to: **Storage** → **Create a new bucket**
3. Settings:
   - Name: `menus`
   - Public: **✅ YES** (important!)
   - Click "Create bucket"

### Step 2: Upload Your Menu

1. Click on the `menus` bucket you just created
2. Click **"Upload file"**
3. Select: `scripts/devils_menu.html`
4. Upload it (you can rename to `devils-menu.html` if you want)

### Step 3: Get Your Public URL

After upload, the URL will be:
```
https://iluhlynzkgubtaswvgwt.supabase.co/storage/v1/object/public/menus/devils-menu.html
```

**Note**: The QR code is already generated for this URL! 🎉

---

## 📱 Using Your QR Code

### Where to Display:

1. **🪟 Window Decals** - Let people see menu before entering
2. **🪑 Table Tents** - On every table for easy ordering
3. **🧾 Receipts** - Include on printed receipts
4. **📄 Takeout Bags** - Sticker on bags
5. **📱 Social Media** - Post on Instagram, Facebook
6. **🖼️ Posters** - At entrance and cashier

### Printing Tips:

- **Small prints (table tents)**: 5cm x 5cm minimum
- **Medium (posters)**: 10cm x 10cm
- **Large (window)**: 20cm x 20cm or bigger
- Always test scan before mass printing!

---

## 🎨 Customization Ideas

### Want to customize the QR code further?

Visit these free tools:
- **QR Code Monkey**: https://www.qrcode-monkey.com/
  - Add your logo in the center
  - Change colors
  - Add frames with text

- **QR Code Generator**: https://www.qr-code-generator.com/
  - Professional designs
  - Multiple formats
  - Analytics tracking

### Want to customize the menu design?

Edit: `scripts/devils_menu.html`
- Change colors in the `<style>` section
- Modify layout
- Add/remove sections
- Then just re-upload to Supabase!

---

## 🔄 Updating Your Menu

When you add/remove items in your database:

```bash
# 1. Fetch latest data from Supabase
./scripts/create_menu_html.sh

# 2. Generate new HTML
dart run scripts/build_menu_html.dart

# 3. Re-upload to Supabase (same filename, overwrites old file)
# Upload via dashboard or use the upload script
```

**Important**: Since the URL stays the same, your QR code never changes! 🎯

---

## 📊 Your Menu Stats

- **Total Items**: 51
- **Categories**: 5
  1. Burger (12 items)
  2. Saucen (12 items)
  3. Desserts (2 items)
  4. Alkoholfreie Getränke (16 items)
  5. Appetizers (9 items)

- **Price Range**: CHF 1.50 - CHF 14.50
- **Most Expensive**: BBQ Bacon Smashed Burger, The Mountain Burger, Chicken Killer Burger (CHF 14.00 each)

---

## 🎉 You're All Set!

Your menu website is:
- ✅ Modern and professional
- ✅ Mobile-friendly
- ✅ Fast loading
- ✅ Easy to update
- ✅ QR code ready

**Files Location**:
- Menu HTML: `scripts/devils_menu.html`
- QR Code: `scripts/devils_menu_qr_code.png`
- Setup Guide: `scripts/MENU_SETUP_GUIDE.md`

---

## 🆘 Need Help?

**Test the menu locally**:
Open `scripts/devils_menu.html` in any web browser

**Test the QR code**:
Use your phone's camera to scan `scripts/devils_menu_qr_code.png` from your computer screen

**Questions?**
- Check: `scripts/MENU_SETUP_GUIDE.md` for detailed instructions
- The menu is already live-ready, just needs to be uploaded!

---

Made with ❤️ for DEVILS SMASH BURGER 🔥🍔



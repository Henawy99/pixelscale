# How to Print Without Browser Headers/Footers

## 🖨️ The Issue

When printing from a browser, you see:
- **Top of page:** Date, time, and URL
- **Bottom of page:** File path and page numbers

These are **browser default settings**, not part of the contract.

---

## ✅ Solution: Disable Headers/Footers in Print Settings

### **For Chrome (Mac/Windows)**

1. Open the contract file in Chrome
2. Press `Cmd + P` (Mac) or `Ctrl + P` (Windows)
3. In the print dialog, click **"More settings"**
4. **Uncheck** these options:
   - ❌ Headers and footers
5. Click **"Print"** or **"Save as PDF"**

**Visual Guide:**
```
Print Dialog
├── Destination: [PDF / Printer]
├── Pages: All
├── Layout: Portrait
└── More settings ▼
    ├── Paper size: A4
    ├── Margins: Default
    ├── Scale: 100%
    └── ☐ Headers and footers  ← UNCHECK THIS
```

---

### **For Safari (Mac)**

1. Open the contract file in Safari
2. Press `Cmd + P`
3. In the print dialog, look for **"Headers and Footers"**
4. **Uncheck** the box
5. Click **"Print"** or **"Save as PDF"**

**Alternative Method:**
1. Click **"Show Details"** at the bottom of print dialog
2. Find and **uncheck** "Print headers and footers"
3. Click **"Print"**

---

### **For Firefox (Mac/Windows)**

1. Open the contract file in Firefox
2. Press `Cmd + P` (Mac) or `Ctrl + P` (Windows)
3. In the print dialog, click the gear icon (⚙️) or **"More settings"**
4. **Uncheck** "Print headers and footers"
5. Click **"Print"**

---

### **For Edge (Windows)**

1. Open the contract file in Edge
2. Press `Ctrl + P`
3. Click **"More settings"**
4. **Uncheck** "Headers and footers"
5. Click **"Print"**

---

## 🎯 Best Method: Save as PDF First

### Recommended Workflow:

1. **Print to PDF** (with headers/footers disabled)
2. **Open the PDF** file
3. **Print from PDF** (PDF doesn't have browser headers)

### Steps:

**Chrome:**
```
1. Open contract → Cmd/Ctrl + P
2. Destination: "Save as PDF"
3. More settings → Uncheck "Headers and footers"
4. Click "Save"
5. Open saved PDF
6. Print from PDF (clean print!)
```

**Safari:**
```
1. Open contract → Cmd + P
2. Click "PDF" dropdown (bottom-left)
3. Select "Save as PDF"
4. Uncheck "Headers and footers"
5. Save
6. Open saved PDF
7. Print from PDF
```

---

## 📋 Complete Print Settings Checklist

When printing the contract, use these settings:

### Print Dialog Settings:
- **Destination:** Your printer or "Save as PDF"
- **Pages:** All (1-4)
- **Layout:** Portrait
- **Color:** Color (recommended) or Black & white
- **Paper size:** A4 (210 × 297 mm)
- **Margins:** Default (or custom if needed)
- **Scale:** 100% (do NOT scale)
- **Headers and footers:** ❌ **UNCHECKED**
- **Background graphics:** ✅ Checked (to show green headers)

---

## 🖼️ What You Should See

### ✅ Correct (No Headers/Footers):
```
┌─────────────────────────────────┐
│                                 │
│  [Playmaker Logo & Header]      │
│  Contract Content...            │
│                                 │
│                                 │
│  [Signature Boxes]              │
│  Page 1 of 4                    │ ← Your page number (part of design)
└─────────────────────────────────┘
```

### ❌ Wrong (With Browser Headers):
```
file:///Users/.../contract.html        Jan 28, 2025 2:30 PM  ← Remove this
┌─────────────────────────────────┐
│  [Playmaker Logo & Header]      │
│  Contract Content...            │
│  [Signature Boxes]              │
│  Page 1 of 4                    │
└─────────────────────────────────┘
/Users/.../playmakerstart/assets/contracts/...  Page 1 of 4  ← Remove this
```

---

## 💡 Pro Tips

### Tip 1: Create a PDF Template
1. Print to PDF once with correct settings
2. Save this PDF as your "master template"
3. Always print from this PDF (no headers issue)

### Tip 2: Use Print Preview
Before printing, check the preview:
- No date/time at top? ✅
- No file path at bottom? ✅
- All content visible? ✅

### Tip 3: Save Your Print Settings (Chrome)
Chrome remembers your last settings, so:
1. Disable headers once
2. Next time you print, it's already disabled!

### Tip 4: Use a PDF Editor
For final production:
1. Save as PDF
2. Open in Adobe Acrobat or Preview
3. Print from there (guaranteed clean)

---

## 🎨 Alternative: Use Browser Extensions

### Chrome Extension: "Print Friendly & PDF"
1. Install from Chrome Web Store
2. Click the extension icon
3. Customize and print (no headers)

### Benefits:
- Clean prints every time
- Easy to use
- Saves settings

---

## 📱 If Printing from Mobile

### iOS (Safari):
1. Open contract
2. Tap share button
3. Select "Print"
4. Pinch to preview
5. Headers/footers usually not shown on iOS

### Android (Chrome):
1. Open contract
2. Menu (⋮) → Print
3. Select printer
4. Advanced → Uncheck headers
5. Print

---

## 🔧 Technical Details

The headers/footers you see are controlled by:
- **Browser:** Chrome, Safari, Firefox, etc.
- **Operating System:** Mac, Windows, etc.
- **Print driver:** Printer settings

They are **NOT** part of the HTML contract file.

**That's why** you need to disable them in print settings.

---

## 📞 Quick Reference Card

**Before Printing, Always:**
1. ✅ Open print dialog (Cmd/Ctrl + P)
2. ✅ Click "More settings"
3. ✅ **Uncheck "Headers and footers"**
4. ✅ Verify in print preview
5. ✅ Print or Save as PDF

---

## ✅ Summary

**To remove browser headers and footers:**

1. **Easiest:** Uncheck "Headers and footers" in print settings
2. **Best:** Save as PDF first, then print from PDF
3. **Permanent:** Use PDF as your template

**The contract file itself is clean** - the headers are added by your browser, not the file!

---

**File:** `field_partnership_contract_professional.html`  
**Status:** Print-ready (with correct browser settings)  
**Updated:** January 2025


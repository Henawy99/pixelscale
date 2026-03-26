# Apple Pay Certificate Setup for Paymob

This folder contains all the certificate files needed for Apple Pay integration with Paymob.

## Current Status

| File | Status | Description |
|------|--------|-------------|
| `merchant_private.key` | ✅ Generated | RSA 2048-bit private key for merchant |
| `payment_process.key` | ✅ Generated | ECC prime256v1 key for payment processing |
| `merchant.csr` | ✅ Generated | Certificate Signing Request for merchant |
| `payment_process.csr` | ✅ Generated | CSR for payment processing |
| `merchant_id.cer` | ❌ Needed | Download from Apple Developer Portal |
| `apple_pay.cer` | ❌ Needed | Download from Apple Developer Portal |
| `merchant_certificate.pem` | ❌ Pending | Will be converted from merchant_id.cer |
| `payment_certificate.pem` | ❌ Pending | Will be converted from apple_pay.cer |

---

## Step-by-Step Instructions

### Step 1: Create Merchant ID in Apple Developer Portal

1. Go to https://developer.apple.com/account
2. Click **Certificates, Identifiers & Profiles**
3. In the left sidebar, click **Identifiers**
4. Click the dropdown and select **Merchant IDs**
5. Click the **+** button to register a new Merchant ID
6. Enter:
   - **Description**: `Playmaker Apple Pay`
   - **Identifier**: `merchant.com.playmakercairo.app`
7. Click **Continue** → **Register**

---

### Step 2: Create Apple Pay Merchant Identity Certificate

1. In Apple Developer Portal, go to your newly created Merchant ID
2. Scroll down to **Apple Pay Merchant Identity Certificate**
3. Click **Create Certificate**
4. When prompted to upload a CSR file, upload:
   ```
   merchant.csr (from this folder)
   ```
5. Click **Continue**
6. Click **Download** to get the certificate
7. **IMPORTANT**: Rename the downloaded file to `merchant_id.cer`
8. Move `merchant_id.cer` to this folder

---

### Step 3: Create Apple Pay Payment Processing Certificate

1. Go back to your Merchant ID in Apple Developer Portal
2. Scroll down to **Apple Pay Payment Processing Certificate**
3. Click **Create Certificate**
4. When prompted to upload a CSR file, upload:
   ```
   payment_process.csr (from this folder)
   ```
5. Click **Continue**
6. Click **Download** to get the certificate
7. **IMPORTANT**: Rename the downloaded file to `apple_pay.cer`
8. Move `apple_pay.cer` to this folder

---

### Step 4: Convert .cer files to .pem format

After placing both `.cer` files in this folder, run:

```bash
./generate_apple_pay_certs.sh
```

Or manually convert:

```bash
# Convert Merchant certificate
openssl x509 -inform DER -in merchant_id.cer -out merchant_certificate.pem

# Convert Payment Processing certificate
openssl x509 -inform DER -in apple_pay.cer -out payment_certificate.pem
```

---

### Step 5: Send Files to Paymob

Send all 6 files to Paymob (reply to Rana's email):

**Files to attach:**
1. `merchant_private.key` - Merchant private key
2. `payment_process.key` - Payment processing private key
3. `merchant_id.cer` - Merchant certificate (from Apple)
4. `apple_pay.cer` - Payment processing certificate (from Apple)
5. `merchant_certificate.pem` - Merchant certificate (PEM format)
6. `payment_certificate.pem` - Payment processing certificate (PEM format)

**Also include:**
- Merchant Identifier: `merchant.com.playmakercairo.app`

---

## Email Template for Paymob

```
Subject: RE: Apple Pay Integration - Certificate Files

Hi Rana,

Please find attached all the Apple Pay certificate files as requested:

1. Merchant Key: merchant_private.key
2. Payment Process Key: payment_process.key
3. Merchant Certificate (.cer): merchant_id.cer
4. Payment Processing Certificate (.cer): apple_pay.cer
5. Merchant Certificate (.pem): merchant_certificate.pem
6. Payment Processing Certificate (.pem): payment_certificate.pem

Merchant Identifier: merchant.com.playmakercairo.app

Please let me know if you need anything else to complete the Apple Pay setup.

Best Regards,
Youssef
```

---

## Security Notes

⚠️ **IMPORTANT**: Keep these files secure!

- Never commit `.key` files to git
- Never share `.key` files publicly
- These files are already in `.gitignore`
- Store backups in a secure location

---

## Troubleshooting

### "CSR file format is invalid"
- Make sure you're uploading the correct `.csr` file
- The CSR must match the certificate type (merchant vs payment processing)

### "Certificate download fails"
- Try a different browser
- Check your Apple Developer account permissions

### "openssl command not found"
- macOS: `brew install openssl`
- The script should work out of the box on macOS

---

## Files in This Folder

```
apple_pay_certificates/
├── README.md                    # This file
├── generate_apple_pay_certs.sh  # Certificate generator script
├── merchant_private.key         # ✅ Generated (DO NOT SHARE)
├── payment_process.key          # ✅ Generated (DO NOT SHARE)
├── merchant.csr                 # ✅ Generated (upload to Apple)
├── payment_process.csr          # ✅ Generated (upload to Apple)
├── merchant_id.cer              # ❌ Download from Apple
├── apple_pay.cer                # ❌ Download from Apple
├── merchant_certificate.pem     # ❌ Will be generated
└── payment_certificate.pem      # ❌ Will be generated
```

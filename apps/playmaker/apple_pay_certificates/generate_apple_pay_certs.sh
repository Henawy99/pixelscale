#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
# APPLE PAY CERTIFICATE GENERATOR FOR PAYMOB
# ═══════════════════════════════════════════════════════════════════════════════
# 
# This script generates all the certificate files needed for Apple Pay with Paymob:
# - 2 .key files (merchant + payment process)
# - 2 .cer files (download from Apple Developer Portal)
# - 2 .pem files (converted from .cer files)
#
# ═══════════════════════════════════════════════════════════════════════════════

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

cd "$(dirname "$0")" || exit 1

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}  🍎 APPLE PAY CERTIFICATE GENERATOR FOR PAYMOB${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: GENERATE MERCHANT KEY (RSA)
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}Step 1: Generating Merchant Key (RSA 2048-bit)${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"

if [ ! -f "merchant_private.key" ]; then
    openssl genpkey -algorithm RSA -out merchant_private.key -pkeyopt rsa_keygen_bits:2048
    echo -e "  ${GREEN}✅${NC} Created: merchant_private.key"
else
    echo -e "  ${YELLOW}⚠️${NC}  merchant_private.key already exists (skipping)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: GENERATE PAYMENT PROCESS KEY (ECC)
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}Step 2: Generating Payment Process Key (ECC prime256v1)${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"

if [ ! -f "payment_process.key" ]; then
    openssl ecparam -genkey -name prime256v1 -out payment_process.key
    echo -e "  ${GREEN}✅${NC} Created: payment_process.key"
else
    echo -e "  ${YELLOW}⚠️${NC}  payment_process.key already exists (skipping)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: GENERATE CSR (Certificate Signing Request) FOR MERCHANT
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}Step 3: Generating Merchant CSR (Certificate Signing Request)${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"

if [ ! -f "merchant.csr" ]; then
    openssl req -new -key merchant_private.key -out merchant.csr \
        -subj "/CN=Playmaker Apple Pay Merchant/O=Playmaker/C=EG"
    echo -e "  ${GREEN}✅${NC} Created: merchant.csr"
else
    echo -e "  ${YELLOW}⚠️${NC}  merchant.csr already exists (skipping)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: GENERATE CSR FOR PAYMENT PROCESSING
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}Step 4: Generating Payment Processing CSR${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"

if [ ! -f "payment_process.csr" ]; then
    openssl req -new -key payment_process.key -out payment_process.csr \
        -subj "/CN=Playmaker Apple Pay Payment/O=Playmaker/C=EG"
    echo -e "  ${GREEN}✅${NC} Created: payment_process.csr"
else
    echo -e "  ${YELLOW}⚠️${NC}  payment_process.csr already exists (skipping)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# INSTRUCTIONS FOR .CER FILES
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}📋 MANUAL STEPS REQUIRED${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Step 5: Create Merchant ID in Apple Developer Portal${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo -e "  1. Go to: ${BLUE}https://developer.apple.com/account${NC}"
echo -e "  2. Navigate to: Certificates, Identifiers & Profiles"
echo -e "  3. Go to: Identifiers → Merchant IDs"
echo -e "  4. Click '+' to create new Merchant ID"
echo -e "  5. Enter: ${CYAN}merchant.com.playmakercairo.app${NC}"
echo -e "  6. Save the Merchant ID"
echo ""

echo -e "${BOLD}Step 6: Create Apple Pay Merchant Identity Certificate${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo -e "  1. In Apple Developer Portal, go to your Merchant ID"
echo -e "  2. Click 'Create Certificate' under Apple Pay Merchant Identity"
echo -e "  3. Upload: ${CYAN}merchant.csr${NC} (from this folder)"
echo -e "  4. Download the certificate as: ${CYAN}merchant_id.cer${NC}"
echo -e "  5. Place it in this folder"
echo ""

echo -e "${BOLD}Step 7: Create Apple Pay Payment Processing Certificate${NC}"
echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
echo -e "  1. In Apple Developer Portal, go to your Merchant ID"
echo -e "  2. Click 'Create Certificate' under Apple Pay Payment Processing"
echo -e "  3. Upload: ${CYAN}payment_process.csr${NC} (from this folder)"
echo -e "  4. Download the certificate as: ${CYAN}apple_pay.cer${NC}"
echo -e "  5. Place it in this folder"
echo ""

echo -e "${YELLOW}After downloading both .cer files, run this script again${NC}"
echo -e "${YELLOW}to convert them to .pem format.${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: CONVERT .CER TO .PEM (if .cer files exist)
# ═══════════════════════════════════════════════════════════════════════════════

if [ -f "merchant_id.cer" ]; then
    echo -e "${BOLD}Step 8: Converting Merchant .cer to .pem${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    openssl x509 -inform DER -in merchant_id.cer -out merchant_certificate.pem
    echo -e "  ${GREEN}✅${NC} Created: merchant_certificate.pem"
    echo ""
else
    echo -e "${YELLOW}⏳${NC} Waiting for: merchant_id.cer (download from Apple)"
fi

if [ -f "apple_pay.cer" ]; then
    echo -e "${BOLD}Step 9: Converting Payment Processing .cer to .pem${NC}"
    echo -e "${CYAN}───────────────────────────────────────────────────────────────${NC}"
    openssl x509 -inform DER -in apple_pay.cer -out payment_certificate.pem
    echo -e "  ${GREEN}✅${NC} Created: payment_certificate.pem"
    echo ""
else
    echo -e "${YELLOW}⏳${NC} Waiting for: apple_pay.cer (download from Apple)"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}📊 FILES STATUS${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

check_file() {
    if [ -f "$1" ]; then
        echo -e "  ${GREEN}✅${NC} $1"
    else
        echo -e "  ${RED}❌${NC} $1 ${YELLOW}(missing)${NC}"
    fi
}

echo -e "${BOLD}.key files (generated locally):${NC}"
check_file "merchant_private.key"
check_file "payment_process.key"
echo ""

echo -e "${BOLD}.csr files (upload to Apple):${NC}"
check_file "merchant.csr"
check_file "payment_process.csr"
echo ""

echo -e "${BOLD}.cer files (download from Apple):${NC}"
check_file "merchant_id.cer"
check_file "apple_pay.cer"
echo ""

echo -e "${BOLD}.pem files (converted from .cer):${NC}"
check_file "merchant_certificate.pem"
check_file "payment_certificate.pem"
echo ""

# Check if all files are ready
if [ -f "merchant_private.key" ] && [ -f "payment_process.key" ] && \
   [ -f "merchant_id.cer" ] && [ -f "apple_pay.cer" ] && \
   [ -f "merchant_certificate.pem" ] && [ -f "payment_certificate.pem" ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║${NC}  ${BOLD}🎉 ALL FILES READY! Send these to Paymob:${NC}               ${GREEN}║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Files to send to Paymob:${NC}"
    echo -e "  1. merchant_private.key"
    echo -e "  2. payment_process.key"
    echo -e "  3. merchant_id.cer"
    echo -e "  4. apple_pay.cer"
    echo -e "  5. merchant_certificate.pem"
    echo -e "  6. payment_certificate.pem"
    echo ""
    echo -e "  ${CYAN}Merchant ID:${NC} merchant.com.playmakercairo.app"
    echo ""
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${BOLD}⚠️  INCOMPLETE - Follow steps above to get .cer files${NC}    ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""

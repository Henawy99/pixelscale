#!/bin/bash
# ==========================================
# Setup Android App Signing
# ==========================================

echo "🔐 Setting up Android App Signing..."
echo ""

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if key.properties already exists
if [ -f "android/key.properties" ]; then
    echo "${YELLOW}⚠️  Warning: key.properties already exists!${NC}"
    echo ""
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "${RED}Aborted.${NC}"
        exit 1
    fi
fi

echo "${BLUE}This script will create a keystore for signing your Android apps.${NC}"
echo ""

# Check if keytool is available
if ! command -v keytool &> /dev/null; then
    echo "${RED}❌ ERROR: keytool not found!${NC}"
    echo ""
    echo "keytool is part of the Java Development Kit (JDK)."
    echo "Please install JDK first:"
    echo "  brew install openjdk"
    exit 1
fi

# Prompt for keystore details
echo "${BLUE}📝 Enter keystore details:${NC}"
echo ""

read -p "Key Alias (e.g., playmaker): " KEY_ALIAS
read -sp "Key Password: " KEY_PASSWORD
echo ""
read -sp "Store Password: " STORE_PASSWORD
echo ""
echo ""

# Set keystore path
KEYSTORE_PATH="$HOME/playmaker-keystore.jks"

# Check if keystore already exists
if [ -f "$KEYSTORE_PATH" ]; then
    echo "${YELLOW}⚠️  Keystore already exists at: $KEYSTORE_PATH${NC}"
    echo ""
    read -p "Do you want to use this existing keystore? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        read -p "Enter new keystore path: " KEYSTORE_PATH
    fi
fi

# Generate keystore if it doesn't exist
if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "${BLUE}🔑 Generating new keystore...${NC}"
    keytool -genkey -v -keystore "$KEYSTORE_PATH" -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 -validity 10000 \
        -storepass "$STORE_PASSWORD" -keypass "$KEY_PASSWORD"
    
    if [ $? -eq 0 ]; then
        echo "${GREEN}✅ Keystore generated successfully!${NC}"
    else
        echo "${RED}❌ Failed to generate keystore${NC}"
        exit 1
    fi
else
    echo "${GREEN}✅ Using existing keystore${NC}"
fi

echo ""

# Create key.properties file
echo "${BLUE}📝 Creating key.properties file...${NC}"

cat > android/key.properties << EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$KEYSTORE_PATH
EOF

echo "${GREEN}✅ key.properties created!${NC}"
echo ""

# Add key.properties to .gitignore if not already there
if ! grep -q "key.properties" .gitignore 2>/dev/null; then
    echo "android/key.properties" >> .gitignore
    echo "${GREEN}✅ Added key.properties to .gitignore${NC}"
fi

# Add keystore to .gitignore if not already there
if ! grep -q "*.jks" .gitignore 2>/dev/null; then
    echo "*.jks" >> .gitignore
    echo "${GREEN}✅ Added *.jks to .gitignore${NC}"
fi

echo ""
echo "${GREEN}🎉 Android signing setup complete!${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "${BLUE}📋 Summary:${NC}"
echo "   Keystore: $KEYSTORE_PATH"
echo "   Key Alias: $KEY_ALIAS"
echo "   Config: android/key.properties"
echo ""
echo "${YELLOW}⚠️  IMPORTANT: Backup your keystore file!${NC}"
echo "   Keep this file safe: $KEYSTORE_PATH"
echo "   If you lose it, you cannot update your apps on Google Play!"
echo ""
echo "${BLUE}📤 Next Steps:${NC}"
echo "   1. Backup keystore:        cp $KEYSTORE_PATH ~/Dropbox/playmaker-keystore.jks"
echo "   2. Build USER app:         ./build_android_user.sh"
echo "   3. Build PARTNER app:      ./build_android_partner.sh"
echo ""

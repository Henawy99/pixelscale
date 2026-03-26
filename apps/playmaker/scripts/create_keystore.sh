#!/bin/bash

# 🔑 Create New Android Keystore for Playmaker
# This script creates a new keystore and configures your project

echo "🔑 Creating new Android keystore for Playmaker..."
echo ""
echo "⚠️  IMPORTANT: Save the password you enter!"
echo ""

# Navigate to project directory
cd /Users/youssefelhenawy/Documents/playmakerstart

# Create the keystore
echo "Creating keystore file: upload-keystore-new.jks"
echo ""
echo "You will be asked several questions:"
echo "1. Password (e.g., Playmaker2024!)"
echo "2. Your name"
echo "3. Organization (e.g., Playmaker)"
echo "4. City (e.g., Cairo)"
echo "5. State (e.g., Cairo)"
echo "6. Country code (e.g., EG)"
echo ""

keytool -genkey -v -keystore upload-keystore-new.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Keystore created successfully!"
    echo ""
    echo "📦 File location: $(pwd)/upload-keystore-new.jks"
    echo ""
    echo "🔧 Now updating android/key.properties..."
    
    # Backup old key.properties if it exists
    if [ -f "android/key.properties" ]; then
        mv android/key.properties android/key.properties.backup.$(date +%Y%m%d_%H%M%S)
        echo "   ✓ Backed up old key.properties"
    fi
    
    # Create new key.properties
    cat > android/key.properties << EOF
storePassword=Playmaker2024!
keyPassword=Playmaker2024!
keyAlias=upload
storeFile=$(pwd)/upload-keystore-new.jks
EOF
    
    echo "   ✓ Created new key.properties"
    echo ""
    echo "🔒 CRITICAL: BACKUP YOUR KEYSTORE NOW!"
    echo ""
    echo "Copy these files to a safe location:"
    echo "   1. $(pwd)/upload-keystore-new.jks"
    echo "   2. $(pwd)/android/key.properties"
    echo ""
    echo "Recommended backup locations:"
    echo "   - Google Drive / Dropbox"
    echo "   - External hard drive"
    echo "   - Password manager"
    echo ""
    echo "🧪 Test your build:"
    echo "   flutter build appbundle --release --flavor user"
    echo ""
else
    echo ""
    echo "❌ Keystore creation failed!"
    echo "Please check the error messages above."
fi


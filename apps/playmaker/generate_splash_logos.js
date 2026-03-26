#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Simple PNG generator using Canvas (will check if available)
async function generateLogos() {
    console.log('🎨 Generating splash screen logos...\n');

    // Check if canvas is available
    let Canvas;
    try {
        Canvas = require('canvas');
    } catch (e) {
        console.log('❌ Canvas module not found. Installing...\n');
        const { execSync } = require('child_process');
        try {
            execSync('npm install canvas', { stdio: 'inherit' });
            Canvas = require('canvas');
        } catch (err) {
            console.log('\n❌ Failed to install canvas. Creating basic placeholder files instead.\n');
            createPlaceholders();
            return;
        }
    }

    const { createCanvas } = Canvas;

    // Create assets directory if it doesn't exist
    const assetsDir = path.join(__dirname, 'assets');
    if (!fs.existsSync(assetsDir)) {
        fs.mkdirSync(assetsDir, { recursive: true });
    }

    // ADMIN splash: Black background with "PM ADMIN" white text
    console.log('📱 Creating ADMIN splash logo (Black with "PM ADMIN")...');
    createTextLogo(
        createCanvas,
        ['PM', 'ADMIN'],
        '#000000',
        '#FFFFFF',
        path.join(assetsDir, 'splash_admin.png')
    );

    // PARTNER splash: Blue background with "PM Partner" white text
    console.log('📱 Creating PARTNER splash logo (Blue with "PM Partner")...');
    createTextLogo(
        createCanvas,
        ['PM', 'Partner'],
        '#2563EB',
        '#FFFFFF',
        path.join(assetsDir, 'splash_partner.png')
    );

    console.log('\n🎉 Splash logos created successfully!\n');
    console.log('Next steps:');
    console.log('  1. Run: ./generate_admin_assets.sh');
    console.log('  2. Run: ./generate_partner_assets.sh');
    console.log('  3. Test: ./run_admin_app.sh');
    console.log('  4. Test: ./run_partner_app.sh\n');
}

function createTextLogo(createCanvas, textLines, bgColor, textColor, outputPath) {
    const canvas = createCanvas(1024, 1024);
    const ctx = canvas.getContext('2d');

    // Fill background
    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, 1024, 1024);

    // Setup text
    ctx.fillStyle = textColor;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';

    // First line (larger)
    ctx.font = 'bold 180px Arial';
    ctx.fillText(textLines[0], 512, 400);

    // Second line (smaller)
    ctx.font = 'bold 150px Arial';
    ctx.fillText(textLines[1], 512, 600);

    // Save to file
    const buffer = canvas.toBuffer('image/png');
    fs.writeFileSync(outputPath, buffer);
    console.log(`✅ Created: ${outputPath}`);
}

function createPlaceholders() {
    console.log('Creating simple placeholder files...\n');
    
    const assetsDir = path.join(__dirname, 'assets');
    if (!fs.existsSync(assetsDir)) {
        fs.mkdirSync(assetsDir, { recursive: true });
    }

    // Create minimal 1x1 PNG files as placeholders
    // These are just temporary - user can replace with proper logos later
    
    // Minimal black PNG (1x1)
    const blackPNG = Buffer.from([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
        0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0x60, 0x60, 0x60, 0x00,
        0x00, 0x00, 0x04, 0x00, 0x01, 0x27, 0x6B, 0xEE, 0xC7, 0x00, 0x00, 0x00,
        0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);

    // Minimal blue PNG (1x1)
    const bluePNG = Buffer.from([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
        0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0x64, 0xC8, 0xF0, 0x00,
        0x00, 0x02, 0x85, 0x01, 0x04, 0x8F, 0x6C, 0x8B, 0xC9, 0x00, 0x00, 0x00,
        0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);

    fs.writeFileSync(path.join(assetsDir, 'splash_admin.png'), blackPNG);
    console.log('✅ Created: assets/splash_admin.png (placeholder)');

    fs.writeFileSync(path.join(assetsDir, 'splash_partner.png'), bluePNG);
    console.log('✅ Created: assets/splash_partner.png (placeholder)');

    console.log('\n⚠️  Note: These are minimal placeholder files.');
    console.log('   The splash screens will show solid colors without text.');
    console.log('   Install canvas for proper text logos: npm install canvas\n');
}

// Run
generateLogos().catch(err => {
    console.error('Error:', err);
    createPlaceholders();
});


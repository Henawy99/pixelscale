#!/usr/bin/env python3
"""
Generate text-based splash screen logos for Playmaker apps
No external dependencies needed - uses PIL/Pillow which is commonly available
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
except ImportError:
    print("❌ Error: Pillow (PIL) is required. Install with: pip3 install Pillow")
    exit(1)


def create_text_logo(output_path, bg_color, text_lines, text_color=(255, 255, 255)):
    """
    Create a simple text-based logo
    
    Args:
        output_path: Where to save the PNG
        bg_color: RGB tuple for background (e.g., (0, 0, 0) for black)
        text_lines: List of text lines to display
        text_color: RGB tuple for text color (default white)
    """
    # Create 1024x1024 image
    size = 1024
    img = Image.new('RGB', (size, size), bg_color)
    draw = ImageDraw.Draw(img)
    
    # Try to use a bold system font, fall back to default
    try:
        # Try to find Arial Black or similar bold font
        font_large = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 150)
        font_small = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 120)
    except:
        try:
            # Try Helvetica Bold
            font_large = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 150)
            font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 120)
        except:
            # Fall back to default font
            font_large = ImageFont.load_default()
            font_small = ImageFont.load_default()
    
    # Calculate vertical positioning
    total_height = 0
    line_fonts = []
    for i, line in enumerate(text_lines):
        font = font_large if i == 0 else font_small
        line_fonts.append(font)
        bbox = draw.textbbox((0, 0), line, font=font)
        total_height += (bbox[3] - bbox[1]) + 20  # Add spacing between lines
    
    # Start position (centered vertically)
    y = (size - total_height) // 2
    
    # Draw each line
    for line, font in zip(text_lines, line_fonts):
        bbox = draw.textbbox((0, 0), line, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        x = (size - text_width) // 2
        
        draw.text((x, y), line, fill=text_color, font=font)
        y += text_height + 20
    
    # Save the image
    img.save(output_path, 'PNG')
    print(f"✅ Created: {output_path}")


def main():
    # Create assets directory if it doesn't exist
    assets_dir = "assets"
    if not os.path.exists(assets_dir):
        os.makedirs(assets_dir)
    
    print("🎨 Generating splash screen logos...")
    print("")
    
    # ADMIN splash: Black background with "PM ADMIN" white text
    print("📱 Creating ADMIN splash logo...")
    create_text_logo(
        output_path=os.path.join(assets_dir, "splash_admin.png"),
        bg_color=(0, 0, 0),  # Black
        text_lines=["PM", "ADMIN"],
        text_color=(255, 255, 255)  # White
    )
    
    # PARTNER splash: Blue background with "PM Partner" white text
    print("📱 Creating PARTNER splash logo...")
    create_text_logo(
        output_path=os.path.join(assets_dir, "splash_partner.png"),
        bg_color=(37, 99, 235),  # Blue #2563EB
        text_lines=["PM", "Partner"],
        text_color=(255, 255, 255)  # White
    )
    
    print("")
    print("🎉 Splash logos created successfully!")
    print("")
    print("Next steps:")
    print("  1. Run: ./generate_admin_assets.sh")
    print("  2. Run: ./generate_partner_assets.sh")
    print("  3. Test: ./run_admin_app.sh")
    print("  4. Test: ./run_partner_app.sh")


if __name__ == "__main__":
    main()



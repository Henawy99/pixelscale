#!/usr/bin/env python3
"""
Create proper splash screen logos using pure Python (no external dependencies)
This creates 1024x1024 PNG files with solid colors as a base.
"""

import struct
import zlib

def create_solid_color_png(width, height, r, g, b, filename):
    """Create a PNG file with a solid color"""
    
    def write_chunk(chunk_type, data):
        """Write a PNG chunk"""
        chunk = chunk_type + data
        crc = zlib.crc32(chunk) & 0xffffffff
        return struct.pack('>I', len(data)) + chunk + struct.pack('>I', crc)
    
    # PNG signature
    png_data = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk (image header)
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    png_data += write_chunk(b'IHDR', ihdr_data)
    
    # Create image data (RGB pixels)
    raw_data = b''
    for y in range(height):
        raw_data += b'\x00'  # Filter type (0 = no filter)
        for x in range(width):
            raw_data += bytes([r, g, b])
    
    # IDAT chunk (compressed image data)
    compressed_data = zlib.compress(raw_data, 9)
    png_data += write_chunk(b'IDAT', compressed_data)
    
    # IEND chunk (end of PNG)
    png_data += write_chunk(b'IEND', b'')
    
    # Write to file
    with open(filename, 'wb') as f:
        f.write(png_data)

# Create splash logos
print("🎨 Creating splash screen logos...")
print()

# ADMIN: Black 1024x1024
print("📱 Creating ADMIN splash logo (Black background)...")
create_solid_color_png(1024, 1024, 0, 0, 0, 'assets/splash_admin.png')
print("✅ Created: assets/splash_admin.png")

# PARTNER: Blue 1024x1024 (#2563EB = rgb(37, 99, 235))
print("📱 Creating PARTNER splash logo (Blue background)...")
create_solid_color_png(1024, 1024, 37, 99, 235, 'assets/splash_partner.png')
print("✅ Created: assets/splash_partner.png")

print()
print("🎉 Splash logo base files created!")
print()
print("Note: These are solid color backgrounds.")
print("      The text 'PM ADMIN' and 'PM Partner' will be overlaid by the splash screen config.")
print()
print("Next steps:")
print("  1. Run: ./run_user_app.sh")
print("  2. Run: ./run_admin_app.sh")
print("  3. Run: ./run_partner_app.sh")


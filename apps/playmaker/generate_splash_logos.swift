#!/usr/bin/swift

import Foundation
import CoreGraphics
import ImageIO
import AppKit

func createTextLogo(text: [String], backgroundColor: NSColor, textColor: NSColor, outputPath: String) {
    let size = CGSize(width: 1024, height: 1024)
    
    // Create image
    let image = NSImage(size: size)
    image.lockFocus()
    
    // Fill background
    backgroundColor.setFill()
    NSRect(x: 0, y: 0, width: size.width, height: size.height).fill()
    
    // Setup text attributes
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.alignment = .center
    
    // Calculate total height
    let fontSize1: CGFloat = 180
    let fontSize2: CGFloat = 150
    let spacing: CGFloat = 20
    
    let font1 = NSFont.boldSystemFont(ofSize: fontSize1)
    let font2 = NSFont.boldSystemFont(ofSize: fontSize2)
    
    let attrs1: [NSAttributedString.Key: Any] = [
        .font: font1,
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle
    ]
    
    let attrs2: [NSAttributedString.Key: Any] = [
        .font: font2,
        .foregroundColor: textColor,
        .paragraphStyle: paragraphStyle
    ]
    
    // Measure text
    let text1Size = (text[0] as NSString).size(withAttributes: attrs1)
    let text2Size = (text[1] as NSString).size(withAttributes: attrs2)
    
    let totalHeight = text1Size.height + text2Size.height + spacing
    var y = (size.height - totalHeight) / 2
    
    // Draw first line
    let rect1 = NSRect(x: 0, y: y, width: size.width, height: text1Size.height)
    (text[0] as NSString).draw(in: rect1, withAttributes: attrs1)
    
    y += text1Size.height + spacing
    
    // Draw second line
    let rect2 = NSRect(x: 0, y: y, width: size.width, height: text2Size.height)
    (text[1] as NSString).draw(in: rect2, withAttributes: attrs2)
    
    image.unlockFocus()
    
    // Save as PNG
    if let tiffData = image.tiffRepresentation,
       let bitmapImage = NSBitmapImageRep(data: tiffData),
       let pngData = bitmapImage.representation(using: .png, properties: [:]) {
        try? pngData.write(to: URL(fileURLWithPath: outputPath))
        print("✅ Created: \(outputPath)")
    } else {
        print("❌ Failed to create: \(outputPath)")
    }
}

print("🎨 Generating splash screen logos...")
print("")

// Create assets directory if needed
let fileManager = FileManager.default
let assetsPath = "assets"
if !fileManager.fileExists(atPath: assetsPath) {
    try? fileManager.createDirectory(atPath: assetsPath, withIntermediateDirectories: true)
}

// Generate ADMIN splash: Black background with "PM ADMIN" white text
print("📱 Creating ADMIN splash logo (Black with 'PM ADMIN')...")
createTextLogo(
    text: ["PM", "ADMIN"],
    backgroundColor: NSColor.black,
    textColor: NSColor.white,
    outputPath: "assets/splash_admin.png"
)

// Generate PARTNER splash: Blue background with "PM Partner" white text
print("📱 Creating PARTNER splash logo (Blue with 'PM Partner')...")
createTextLogo(
    text: ["PM", "Partner"],
    backgroundColor: NSColor(red: 37/255, green: 99/255, blue: 235/255, alpha: 1.0), // #2563EB
    textColor: NSColor.white,
    outputPath: "assets/splash_partner.png"
)

print("")
print("🎉 Splash logos created successfully!")
print("")
print("Next steps:")
print("  1. Run: ./generate_admin_assets.sh")
print("  2. Run: ./generate_partner_assets.sh")
print("  3. Test: ./run_admin_app.sh")
print("  4. Test: ./run_partner_app.sh")


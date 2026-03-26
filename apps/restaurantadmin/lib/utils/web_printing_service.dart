// This file handles printing functionality across different platforms
// Uses conditional imports to avoid dart:html on mobile platforms
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
// Conditional imports for web-specific implementation
import 'web_printing_service_stub.dart'
    if (dart.library.html) 'web_printing_service_web.dart';

// Original function, can be kept for direct web printing if needed elsewhere,
// or refactored/removed if printReceiptPlatformSpecific becomes the sole entry point.
void printHtmlOnWeb(String htmlContent, BuildContext context) {
  if (kIsWeb) {
    // Call the web-specific implementation
    printHtmlOnWebImpl(htmlContent, context);
  } else {
    // This case should ideally not be hit if called from a web-only context.
    // printReceiptPlatformSpecific handles non-web cases.
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Web printing called on non-web platform. Use platform-specific printing.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}

Future<void> printReceiptPlatformSpecific(String htmlContent, BuildContext context, String documentName) async {
  if (kIsWeb) {
    // Use existing web implementation
    printHtmlOnWebImpl(htmlContent, context);
    // Navigation for web will be handled in the calling widget (CartViewWidget)
    // as html.window.print() is synchronous in terms of dialog appearance.
  } else if (defaultTargetPlatform == TargetPlatform.windows ||
             defaultTargetPlatform == TargetPlatform.linux ||
             defaultTargetPlatform == TargetPlatform.macOS) {
    try {
      await Printing.layoutPdf(
        onLayout: (format) async {
          return await Printing.convertHtml(
            format: format,
            html: htmlContent,
          );
        },
        name: documentName, // e.g., 'Receipt_Order_XYZ'
      );
      // Navigation for desktop will be handled in the calling widget after this future completes.
    } catch (e) {
      print('Error printing on desktop: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing receipt: $e'), backgroundColor: Colors.red),
        );
      }
    }
  } else {
    // Handle other platforms (e.g., mobile, though printing is less common or needs different setup)
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printing is not yet configured for this mobile platform.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }
}
